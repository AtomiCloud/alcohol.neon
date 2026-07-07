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
# codemagic-cli-tools saves profiles to the Xcode 16 location
# (~/Library/Developer/Xcode/UserData) — keep the classic path too.
PROFILE_DIRS=(
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  "$HOME/Library/MobileDevice/Provisioning Profiles"
)

fail=0
tmp_plist=$(mktemp)
trap 'rm -f "$tmp_plist"' EXIT
while IFS= read -r target_id; do
  found=""
  for dir in "${PROFILE_DIRS[@]}"; do
    for profile in "$dir"/*.mobileprovision; do
      [ -e "$profile" ] || continue
      security cms -D -i "$profile" >"$tmp_plist" 2>/dev/null || continue
      # PlistBuddy, not plutil keypaths: the dotted entitlement key needs
      # plutil's `\.` escaping, which the CI runner's macOS doesn't support —
      # it silently extracted nothing and failed every release with a bogus
      # "profile lacks App Group". PlistBuddy paths are colon-separated, so
      # dotted key names need no escaping at all.
      app_id=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$tmp_plist" 2>/dev/null) || continue
      # application-identifier is TEAMID.<bundle id>
      [ "${app_id#*.}" = "$target_id" ] || continue
      found=$profile
      groups=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.security.application-groups" "$tmp_plist" 2>/dev/null) || groups=""
      if printf '%s' "$groups" | grep -qF "$EXPECTED_GROUP"; then
        echo "doctor: OK    $target_id ← $EXPECTED_GROUP"
      else
        echo "doctor: FAIL  $target_id — profile lacks App Group $EXPECTED_GROUP" >&2
        echo "    application-groups in profile: ${groups:-<key absent>}" >&2
        echo "  → the group must be ticked on this App ID in the Apple Developer" >&2
        echo "    portal (Identifiers → App ID → App Groups → Configure) and the" >&2
        echo "    stale profile rotated ('pls register' rotates), then re-run." >&2
        echo "    See docs/developer/standard/bundle-id.md." >&2
        fail=1
      fi
      break 2
    done
  done
  if [ -z "$found" ]; then
    echo "doctor: FAIL  $target_id — no provisioning profile fetched for it" >&2
    fail=1
  fi
done <<<"$TARGETS"

exit "$fail"
