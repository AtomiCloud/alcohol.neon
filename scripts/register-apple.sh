#!/usr/bin/env bash
set -euo pipefail

# Registers everything Apple-side that CI's API key cannot — run by an App
# Manager/Admin, locally, with their own Apple ID. Idempotent: re-run any time
# a new signing target (widget, watch app, …) or landscape is added.
#
# Flow: one interactive sign-in up front (password + a single 2FA prompt on
# this terminal — fastlane caches the session locally), then every landscape
# is processed automatically and non-interactively.
#
# Per landscape it ensures:
#   1. the App Group          group.<app bundle id>
#   2. every App ID           (app + extensions, discovered from the Xcode project)
#   3. the App Groups capability on each App ID
#   4. the group ⇄ App ID association
#   5. the App Store Connect  app record (the store bucket TestFlight uploads
#      into) — and writes its numeric apple_id into scripts/ci/cd-matrix.sh
#
# The ONE Apple-side thing it can't do: free up an app NAME still held by a
# pre-migration app record. If a name is taken, that landscape is reported at
# the end — rename the old app in App Store Connect and re-run.
# Google Play app creation has no API at all; those stay manual (see
# docs/migration-lpsm-ids.md).
#
# CI/CD never needs this: it stays API-key-only (fetch-signing-files --create
# self-heals certs/profiles) and scripts/ci/doctor-ios.sh verifies the group is
# wired by decoding the fetched profiles.
#
# Env:
#   FASTLANE_USER          Apple ID email (skips the prompt)
#   FASTLANE_TEAM_ID       Developer-portal team (skips the team menu)
#   FASTLANE_ITC_TEAM_ID   App Store Connect team (skips the team menu)
#
# Usage: ./scripts/register-apple.sh [landscape ...]   (default: ALL — pichu pikachu raichu)

# The team this project releases under — preselected in the team menu.
PROJECT_TEAM_ID=SY4WNY5G7U

export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_OPT_OUT_USAGE=1
export FASTLANE_HIDE_CHANGELOG=1

LANDSCAPES=("$@")
[ ${#LANDSCAPES[@]} -gt 0 ] || LANDSCAPES=(pichu pikachu raichu)

HERE="$(cd "$(dirname "$0")" && pwd)"
MATRIX="$HERE/ci/cd-matrix.sh"

if ! command -v fastlane >/dev/null; then
  echo "✗ fastlane not found — run this inside the dev shell (direnv / nix develop)." >&2
  exit 1
fi

# The public-facing App Store name per landscape. Prod gets the bare name;
# other landscapes are suffixed so all three can coexist (store names are
# globally unique). Override the base with NEON_APP_NAME=… ; individual names
# can also be edited later in App Store Connect (freely before first release).
APP_NAME=${NEON_APP_NAME:-LazyTax}
store_name() {
  case $1 in
  raichu) echo "$APP_NAME" ;;
  pichu) echo "$APP_NAME (Pichu)" ;;
  pikachu) echo "$APP_NAME (Pikachu)" ;;
  *) echo "$APP_NAME ($1)" ;;
  esac
}

# ── 1. Sign in once, interactively ──────────────────────────────────────────
# Everything after this runs with output captured (for error triage), which
# breaks interactive prompts — so all interaction happens here, on the TTY.
APPLE_ID=${FASTLANE_USER:-}
if [ -z "$APPLE_ID" ]; then
  read -r -p "Apple ID email (needs App Manager/Admin role): " APPLE_ID </dev/tty
fi
export FASTLANE_USER="$APPLE_ID"

echo
echo "==> Signing in to the Apple Developer portal as $APPLE_ID"
echo "    Expect a password prompt and one 2FA code. fastlane will then print a"
echo "    long FASTLANE_SESSION blob — ignore it; the session is cached locally."
echo
fastlane spaceauth -u "$APPLE_ID"

# Throwaway Fastfile: team enumeration + apple_id lookup lanes, run with
# fastlane's own ruby/gems so Spaceship is available.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/fastlane"
cat >"$tmpdir/fastlane/Fastfile" <<'RUBY'
lane :teams do
  require "spaceship"
  Spaceship::Portal.login(ENV["FASTLANE_USER"])
  Spaceship::Portal.client.teams.each do |t|
    puts "TEAM\t#{t["teamId"]}\t#{t["name"]}"
  end
  Spaceship::Tunes.login(ENV["FASTLANE_USER"])
  Spaceship::Tunes.client.teams.each do |t|
    puts "ITCTEAM\t#{t["contentProvider"]["contentProviderId"]}\t#{t["contentProvider"]["name"]}"
  end
end

lane :appids do
  require "spaceship"
  Spaceship::Tunes.login(ENV["FASTLANE_USER"])
  Spaceship::Tunes.select_team
  ENV["NEON_BUNDLE_IDS"].split(",").each do |bid|
    app = Spaceship::Tunes::Application.find(bid)
    puts "APP\t#{bid}\t#{app ? app.apple_id : ""}"
  end
end
RUBY

# ── 2. Pick the teams ─────────────────────────────────────────────────────────
# An Apple ID can belong to several teams — on BOTH sides: the Developer portal
# (signing) and App Store Connect (store records) have separate team ids.
# fastlane's own chooser would fire mid-loop where output is captured (an
# invisible hang), so enumerate and choose everything up front.
echo
echo "==> Looking up your teams…"
team_lines=$( (cd "$tmpdir" && fastlane teams 2>&1) | grep -E $'^(TEAM|ITCTEAM)\t' || true)

# pick_team <label> <lines> <default_id> — prints the chosen id.
pick_team() {
  local label=$1 lines=$2 default_id=$3
  local n
  n=$(wc -l <<<"$lines")
  if [ "$n" -eq 1 ]; then
    echo "  ✓ $label team: $(cut -f3 <<<"$lines") ($(cut -f2 <<<"$lines"))" >&2
    cut -f2 <<<"$lines"
    return
  fi
  echo "Your Apple ID belongs to multiple $label teams:" >&2
  local i=0 default_idx=1 tid tname
  while IFS=$'\t' read -r _ tid tname; do
    i=$((i + 1))
    local marker=""
    if [ "$tid" = "$default_id" ]; then
      marker="   ← this project's team"
      default_idx=$i
    fi
    echo "  $i) $tname ($tid)$marker" >&2
  done <<<"$lines"
  local sel
  read -r -p "Select $label team [$default_idx]: " sel </dev/tty
  sel=${sel:-$default_idx}
  local chosen
  chosen=$(sed -n "${sel}p" <<<"$lines" | cut -f2)
  if [ -z "$chosen" ]; then
    echo "✗ invalid selection: $sel" >&2
    exit 1
  fi
  echo "$chosen"
}

portal_teams=$(grep $'^TEAM\t' <<<"$team_lines" || true)
itc_teams=$(grep $'^ITCTEAM\t' <<<"$team_lines" || true)

if [ -z "${FASTLANE_TEAM_ID:-}" ]; then
  if [ -z "$portal_teams" ]; then
    echo "  (could not enumerate portal teams — using the project team $PROJECT_TEAM_ID)"
    FASTLANE_TEAM_ID=$PROJECT_TEAM_ID
  elif ! grep -q $'^TEAM\t'"$PROJECT_TEAM_ID"$'\t' <<<"$portal_teams" &&
    [ -z "${NEON_ALLOW_FOREIGN_TEAM:-}" ]; then
    # Registering App IDs/Groups into the wrong team (e.g. a personal one) makes
    # them invisible to CI, whose API key belongs to the project team — refuse.
    echo "✗ Your Apple ID has NO Developer-portal access to the project team ($PROJECT_TEAM_ID)." >&2
    echo >&2
    echo "  Portal teams your Apple ID can see:" >&2
    cut -f2,3 <<<"$portal_teams" | sed 's/^/    - /' >&2
    echo >&2
    echo "  App Store Connect and the Developer portal have SEPARATE access: you can" >&2
    echo "  be on the ASC team yet lack the signing side. An org Admin must grant your" >&2
    echo "  user 'Access to Certificates, Identifiers & Profiles' (App Store Connect →" >&2
    echo "  Users and Access → your user → Developer Resources), or an Admin runs this." >&2
    echo >&2
    echo "  To intentionally register under a different team anyway:" >&2
    echo "    NEON_ALLOW_FOREIGN_TEAM=1 pls register" >&2
    exit 1
  else
    FASTLANE_TEAM_ID=$(pick_team "Developer-portal" "$portal_teams" "$PROJECT_TEAM_ID")
  fi
fi
export FASTLANE_TEAM_ID

if [ -z "${FASTLANE_ITC_TEAM_ID:-}" ] && [ -n "$itc_teams" ]; then
  FASTLANE_ITC_TEAM_ID=$(pick_team "App Store Connect" "$itc_teams" "")
  export FASTLANE_ITC_TEAM_ID
fi
echo "==> Registering under portal team $FASTLANE_TEAM_ID${FASTLANE_ITC_TEAM_ID:+, ASC team $FASTLANE_ITC_TEAM_ID}"

# ── helpers ──────────────────────────────────────────────────────────────────
# All run a fastlane command silently and print a one-line result; on a real
# failure they dump fastlane's full output. `ensure` additionally tolerates the
# benign "resource already exists" failure (the idempotent re-run case).
run() {
  local label=$1
  shift
  local out
  if out=$("$@" 2>&1); then
    echo "  ✓ $label"
    return 0
  fi
  echo "  ✗ $label" >&2
  printf '%s\n' "$out" >&2
  return 1
}

ensure() {
  local label=$1
  shift
  local out
  if out=$("$@" 2>&1); then
    echo "  ✓ $label (created)"
    return 0
  fi
  if grep -qiE "already exist|already been taken" <<<"$out"; then
    echo "  ✓ $label (already exists)"
    return 0
  fi
  echo "  ✗ $label" >&2
  printf '%s\n' "$out" >&2
  return 1
}

# Like `ensure`, but for the ASC app record: a name conflict (the old app still
# holds the store name) is reported and skipped instead of failing the run.
# Returns 0 ok/exists, 2 name conflict, 1 real error.
ensure_record() {
  local label=$1
  shift
  local out
  if out=$("$@" 2>&1); then
    echo "  ✓ $label"
    return 0
  fi
  if grep -qiE "already being used|is not available" <<<"$out"; then
    echo "  ⚠ $label — the store NAME is taken (rename the old app, then re-run)"
    return 2
  fi
  if grep -qiE "already exist" <<<"$out"; then
    echo "  ✓ $label (already exists)"
    return 0
  fi
  echo "  ✗ $label" >&2
  printf '%s\n' "$out" >&2
  return 1
}

# ── 3. Register every landscape ──────────────────────────────────────────────
PENDING_RENAME=()
APP_IDS=()
for L in "${LANDSCAPES[@]}"; do
  # Captured (not process-substituted) so a discovery failure aborts the run.
  targets=$("$HERE/ci/ios-signing-targets.sh" "$L")
  # The App Group is `group.` + the app's bundle id — the first (shortest) target.
  app_bundle_id="${targets%%$'\n'*}"
  GROUP="group.$app_bundle_id"
  APP_IDS+=("$app_bundle_id")

  echo
  echo "==> $L"
  ensure "App Group $GROUP" \
    fastlane produce group -g "$GROUP" -n "LazyTax $L shared"

  while IFS= read -r bundle_id; do
    module=${bundle_id#cloud.atomi."$L".alcohol.neon}
    module=${module#.}
    name="LazyTax $L${module:+ $module}"

    ensure "App ID $bundle_id" \
      fastlane produce -a "$bundle_id" --app_name "$name" --skip_itc
    run "  App Groups capability on $bundle_id" \
      fastlane produce enable_services --app-group -a "$bundle_id"
    run "  associate $GROUP" \
      fastlane produce associate_group -a "$bundle_id" "$GROUP"
  done <<<"$targets"

  # The store app record (main app only — extensions ship inside the app).
  rc=0
  ensure_record "ASC app record '$(store_name "$L")' ($app_bundle_id)" \
    fastlane produce -a "$app_bundle_id" \
    --app_name "$(store_name "$L")" \
    --sku "$app_bundle_id" \
    --language en-US || rc=$?
  if [ "$rc" -eq 2 ]; then
    PENDING_RENAME+=("$L")
  elif [ "$rc" -ne 0 ]; then
    exit "$rc"
  fi
done

# ── 4. Fill apple_ids into the CD matrix ──────────────────────────────────────
# The numeric ASC app id feeds get-latest-build-number in CD; look each one up
# and patch scripts/ci/cd-matrix.sh in place.
echo
echo "==> Looking up numeric apple_ids…"
ids=$(
  cd "$tmpdir" &&
    NEON_BUNDLE_IDS=$(
      IFS=,
      echo "${APP_IDS[*]}"
    ) fastlane appids 2>&1 | grep $'^APP\t' || true
)
patched=0
while IFS=$'\t' read -r _ bid aid; do
  [ -n "$bid" ] && [ -n "$aid" ] || continue
  land=$(cut -d. -f3 <<<"$bid")
  if grep -q "{\"flavor\":\"$land\",\"apple_id\":\"$aid\"}" "$MATRIX"; then
    echo "  ✓ $land: apple_id $aid (already in cd-matrix.sh)"
    continue
  fi
  sed -i.bak "s|{\"flavor\":\"$land\",\"apple_id\":\"[^\"]*\"}|{\"flavor\":\"$land\",\"apple_id\":\"$aid\"}|" "$MATRIX"
  rm -f "$MATRIX.bak"
  echo "  ✓ $land: apple_id $aid → written to cd-matrix.sh"
  patched=1
done <<<"$ids"
[ -n "$ids" ] || echo "  (no records found yet — nothing to fill)"

# ── 5. Summary ────────────────────────────────────────────────────────────────
echo
echo "Done — ${#LANDSCAPES[@]} landscape(s): ${LANDSCAPES[*]}"
echo "CI verifies the signing wiring on every release (scripts/ci/doctor-ios.sh)."
if [ ${#PENDING_RENAME[@]} -gt 0 ]; then
  echo
  echo "⚠ Store names still held by the old apps for: ${PENDING_RENAME[*]}"
  echo "  → In App Store Connect, rename the old app(s) (e.g. suffix ' OLD'),"
  echo "    then re-run: pls register"
fi
if [ "$patched" -eq 1 ]; then
  echo
  echo "cd-matrix.sh was updated with apple_id(s) — review and commit it:"
  echo "  git diff scripts/ci/cd-matrix.sh"
fi
echo
echo "Still manual (no API exists) — see docs/migration-lpsm-ids.md:"
echo "  • Google Play Console apps"
echo "  • Logto redirect URIs"
echo
echo "If a step hangs, the cached Apple session likely expired — re-run this script."
