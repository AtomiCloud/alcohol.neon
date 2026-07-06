#!/usr/bin/env bash
set -euo pipefail

# Registers everything Apple's portal needs for signing that has NO App Store
# Connect API — run by an App Manager/Admin, locally, with their own Apple ID
# (fastlane Spaceship; expect one 2FA prompt). Idempotent: re-run any time a new
# signing target (widget, watch app, …) is added, or after adding a landscape.
#
# Per landscape it ensures:
#   1. the App Group        group.cloud.atomi.<landscape>.alcohol.neon
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
#   FASTLANE_USER      Apple ID email of the App Manager running this (prompted if unset)
#   FASTLANE_TEAM_ID   Apple Developer team (defaults to the project's team)
#
# Usage: ./scripts/register-apple.sh [landscape ...]   (default: pichu pikachu raichu)

export FASTLANE_TEAM_ID=${FASTLANE_TEAM_ID:-SY4WNY5G7U}
export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_OPT_OUT_USAGE=1

LANDSCAPES=("$@")
[ ${#LANDSCAPES[@]} -gt 0 ] || LANDSCAPES=(pichu pikachu raichu)

HERE="$(cd "$(dirname "$0")" && pwd)"

# Runs a fastlane command whose only benign failure is "resource already exists"
# (the idempotent re-run case). Output streams live (Apple ID / 2FA prompts) and
# is captured, so a real failure — auth, network, permissions — still aborts
# loudly instead of masquerading as already-registered.
tolerate_exists() {
  local out
  if out=$("$@" 2>&1 | tee /dev/stderr); then return 0; fi
  if grep -qiE "already exist|already been taken|is not available" <<<"$out"; then
    echo "    (already exists — continuing)"
    return 0
  fi
  return 1
}

for L in "${LANDSCAPES[@]}"; do
  # Captured (not process-substituted) so a discovery failure aborts the run.
  targets=$("$HERE/ci/ios-signing-targets.sh" "$L")
  # The App Group is `group.` + the app's bundle id — the first (shortest) target.
  GROUP="group.${targets%%$'\n'*}"

  echo "==> [$L] ensure App Group $GROUP"
  tolerate_exists fastlane produce group -g "$GROUP" -n "LazyTax $L shared"

  while IFS= read -r bundle_id; do
    module=${bundle_id#cloud.atomi."$L".alcohol.neon}
    module=${module#.}
    name="LazyTax $L${module:+ $module}"

    echo "==> [$L] ensure App ID $bundle_id"
    tolerate_exists fastlane produce -a "$bundle_id" --app_name "$name" --skip_itc

    echo "==> [$L] enable App Groups capability on $bundle_id"
    fastlane produce enable_services --app-group -a "$bundle_id"

    echo "==> [$L] associate $GROUP with $bundle_id"
    fastlane produce associate_group -a "$bundle_id" "$GROUP"
  done <<<"$targets"
done

echo
echo "Done. CI verifies this wiring on every release (scripts/ci/doctor-ios.sh)."
echo "Still manual (no API exists): App Store Connect app records + Play Console"
echo "apps for new landscapes — see docs/migration-lpsm-ids.md."
