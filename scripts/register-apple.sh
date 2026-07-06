#!/usr/bin/env bash
set -euo pipefail

# Registers everything Apple's portal needs for signing that has NO App Store
# Connect API — run by an App Manager/Admin, locally, with their own Apple ID.
# Idempotent: re-run any time a new signing target (widget, watch app, …) is
# added, or after adding a landscape.
#
# Flow: one interactive sign-in up front (password + a single 2FA prompt on
# this terminal — fastlane caches the session locally), then every landscape
# is processed automatically and non-interactively.
#
# Per landscape it ensures:
#   1. the App Group        group.<app bundle id>
#   2. every App ID          (app + extensions, discovered from the Xcode project)
#   3. the App Groups capability on each App ID
#   4. the group ⇄ App ID association
#
# What it does NOT do (store app records have no creation API either — see
# docs/migration-lpsm-ids.md): App Store Connect app records, Play Console apps.
#
# CI/CD never needs this: it stays API-key-only (fetch-signing-files --create
# self-heals certs/profiles) and scripts/ci/doctor-ios.sh verifies the group is
# wired by decoding the fetched profiles.
#
# Env:
#   FASTLANE_USER      Apple ID email (skips the prompt)
#   FASTLANE_TEAM_ID   Apple Developer team (defaults to the project's team)
#
# Usage: ./scripts/register-apple.sh [landscape ...]   (default: ALL — pichu pikachu raichu)

export FASTLANE_TEAM_ID=${FASTLANE_TEAM_ID:-SY4WNY5G7U}
export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_OPT_OUT_USAGE=1
export FASTLANE_HIDE_CHANGELOG=1

LANDSCAPES=("$@")
[ ${#LANDSCAPES[@]} -gt 0 ] || LANDSCAPES=(pichu pikachu raichu)

HERE="$(cd "$(dirname "$0")" && pwd)"

if ! command -v fastlane >/dev/null; then
  echo "✗ fastlane not found — run this inside the dev shell (direnv / nix develop)." >&2
  exit 1
fi

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

# ── helpers ──────────────────────────────────────────────────────────────────
# Both run a fastlane command silently and print a one-line result; on a real
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
  if grep -qiE "already exist|already been taken|is not available" <<<"$out"; then
    echo "  ✓ $label (already exists)"
    return 0
  fi
  echo "  ✗ $label" >&2
  printf '%s\n' "$out" >&2
  return 1
}

# ── 2. Register every landscape ──────────────────────────────────────────────
for L in "${LANDSCAPES[@]}"; do
  # Captured (not process-substituted) so a discovery failure aborts the run.
  targets=$("$HERE/ci/ios-signing-targets.sh" "$L")
  # The App Group is `group.` + the app's bundle id — the first (shortest) target.
  GROUP="group.${targets%%$'\n'*}"

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
done

# ── 3. Summary ────────────────────────────────────────────────────────────────
echo
echo "Done — ${#LANDSCAPES[@]} landscape(s) registered: ${LANDSCAPES[*]}"
echo "CI verifies this wiring on every release (scripts/ci/doctor-ios.sh)."
echo
echo "Still manual (no API exists) — see docs/migration-lpsm-ids.md:"
echo "  • App Store Connect app records (then fill apple_id in scripts/ci/cd-matrix.sh)"
echo "  • Google Play Console apps"
echo "  • Logto redirect URIs"
echo
echo "If a step hangs, the cached Apple session likely expired — re-run this script."
