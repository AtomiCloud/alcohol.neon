#!/usr/bin/env bash
set -euo pipefail

# Tests the stamp-ios.sh Info.plist helpers against the real ios/Runner/
# Info.plist, expanded the way Xcode expands it for the raichu donor.
# macOS only. Run with `pls test:ios-stamp`; cd-ios.sh runs it before the build.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/ci/stamp-ios-lib.sh disable=SC1091
source "$ROOT/scripts/ci/stamp-ios-lib.sh"

OLD=cloud.atomi.raichu.alcohol.neon.app
NEW=cloud.atomi.pichu.alcohol.neon.app
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PLIST="$WORK/Info.plist"
sed -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$OLD/g" -e "s/\$(NEON_APP_GROUP)/group.$OLD/g" \
  "$ROOT/ios/Runner/Info.plist" >"$PLIST"
pb() { /usr/libexec/PlistBuddy -c "$1" "$PLIST"; }
fail() {
  echo "stamp-ios-test: $1" >&2
  exit 1
}

# The guard catches a donor id left behind.
if assert_no_donor_id "$PLIST" "$OLD" 2>/dev/null; then
  fail "assert_no_donor_id passed on an unstamped plist"
fi

# The URL scheme follows the new bundle id.
restamp_url_schemes "$PLIST" "$OLD" "$NEW"
[ "$(pb 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0')" = "$NEW" ] || fail "URL scheme not restamped"
[ "$(pb 'Print :CFBundleURLTypes:0:CFBundleURLName')" = "$NEW" ] || fail "URL name not restamped"

# With the fields stamp-ios.sh already sets, nothing of the donor is left.
pb "Set :CFBundleIdentifier $NEW"
pb "Set :NeonAppGroup group.$NEW"
assert_no_donor_id "$PLIST" "$OLD" || fail "donor id still present after stamping"

echo "stamp-ios-test: ok"
