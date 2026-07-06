#!/usr/bin/env bash
set -euo pipefail

# Verifies the fetched provisioning profiles actually carry the App Group
# entitlement for every signing target of one landscape. Group⇄bundle-id
# association is invisible to the App Store Connect API, but Apple bakes the
# group into the profile — so decoding the profiles is the one deterministic,
# API-key-only way to check the portal is wired up.
#
# Fails with the exact fix when a target is missing its group: run
# `pls register` (an App Manager's one-time 2FA action per new target).
#
# macOS only (uses `security cms`); runs in CD right after fetch-signing-files.
#
# Usage: ./scripts/ci/doctor-ios.sh <landscape>

LANDSCAPE=${1:?usage: doctor-ios.sh <landscape>}
# Captured (not a process substitution) so a discovery failure aborts the doctor
# instead of being swallowed as an empty loop.
TARGETS=$(./scripts/ci/ios-signing-targets.sh "$LANDSCAPE")
# The App Group is `group.` + the app's bundle id — the first (shortest) target.
EXPECTED_GROUP="group.${TARGETS%%$'\n'*}"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

fail=0
while IFS= read -r target_id; do
  found=""
  for profile in "$PROFILE_DIR"/*.mobileprovision; do
    [ -e "$profile" ] || continue
    plist=$(security cms -D -i "$profile" 2>/dev/null) || continue
    app_id=$(printf '%s' "$plist" |
      plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null) || continue
    # application-identifier is TEAMID.<bundle id>
    [ "${app_id#*.}" = "$target_id" ] || continue
    found=$profile
    groups=$(printf '%s' "$plist" |
      plutil -extract 'Entitlements.com\.apple\.security\.application-groups' json -o - - 2>/dev/null) || groups=""
    if printf '%s' "$groups" | grep -q "\"$EXPECTED_GROUP\""; then
      echo "doctor: OK    $target_id ← $EXPECTED_GROUP"
    else
      echo "doctor: FAIL  $target_id — profile lacks App Group $EXPECTED_GROUP" >&2
      echo "  → an App Manager must run 'pls register' (creates the group and" >&2
      echo "    ticks it on the bundle id in the Apple Developer portal), then" >&2
      echo "    re-run this workflow. See docs/developer/standard/bundle-id.md." >&2
      fail=1
    fi
    break
  done
  if [ -z "$found" ]; then
    echo "doctor: FAIL  $target_id — no provisioning profile fetched for it" >&2
    fail=1
  fi
done <<<"$TARGETS"

exit "$fail"
