#!/usr/bin/env bash
set -euo pipefail

# Info.plist helpers for scripts/ci/stamp-ios.sh, kept separate so
# scripts/ci/stamp-ios-test.sh can exercise them without signing files.
# macOS only (PlistBuddy, plutil).

# Re-points the app's own URL scheme: Info.plist registers
# $(PRODUCT_BUNDLE_IDENTIFIER) as a CFBundleURLSchemes entry (the Strava/OAuth
# redirect target), which Xcode expanded to the donor's bundle id. Every
# CFBundleURLName or scheme equal to <old-id> becomes <new-id>.
restamp_url_schemes() {
  local plist=$1 old=$2 new=$3 i=0 j cur
  while [ -n "$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:$i" "$plist" 2>/dev/null)" ]; do
    cur=$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:$i:CFBundleURLName" "$plist" 2>/dev/null || true)
    if [ "$cur" = "$old" ]; then
      /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:$i:CFBundleURLName $new" "$plist"
    fi
    j=0
    while :; do
      cur=$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:$i:CFBundleURLSchemes:$j" "$plist" 2>/dev/null || true)
      [ -n "$cur" ] || break
      if [ "$cur" = "$old" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:$i:CFBundleURLSchemes:$j $new" "$plist"
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
}

# Fails when the donor's bundle id is still anywhere in a stamped plist, so a
# future build-time key that expands to it can't silently ship (it broke the
# Strava redirect on pichu and pikachu once).
assert_no_donor_id() {
  local plist=$1 old=$2
  if plutil -convert xml1 -o - "$plist" | grep -qF "$old"; then
    echo "stamp-ios doctor: $plist still contains the donor id $old:" >&2
    plutil -convert xml1 -o - "$plist" | grep -nF "$old" >&2
    return 1
  fi
}
