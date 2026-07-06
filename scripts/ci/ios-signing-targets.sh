#!/usr/bin/env bash
set -euo pipefail

# Prints every iOS bundle id that needs signing files for one landscape — the app
# plus every embedded extension (widgets, future watch apps, …) — one per line,
# app first. Discovered from the Xcode project, so adding a new extension target
# is picked up automatically; nothing to edit here.
#
# LPSM ids: cloud.atomi.<landscape>.<platform>.<service>[.<module>...]. The
# `.tests` module is excluded (unit-test bundles are never archived/shipped).
#
# Usage: ./scripts/ci/ios-signing-targets.sh <landscape>   (e.g. pichu)

LANDSCAPE=${1:?usage: ios-signing-targets.sh <landscape>}
PBXPROJ="$(dirname "$0")/../../ios/Runner.xcodeproj/project.pbxproj"

sed -n "s/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = \(cloud\.atomi\.$LANDSCAPE\.[a-z.]*\);$/\1/p" "$PBXPROJ" |
  grep -v '\.tests$' |
  sort -u |
  awk '{ print length, $0 }' | sort -n | cut -d' ' -f2-
