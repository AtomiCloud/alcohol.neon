#!/usr/bin/env bash
set -euo pipefail

# Stamps the donor IPA into ONE landscape's release IPA (scripts/ci/
# stamp-ios.sh): fetch + doctor the landscape's signing files, re-badge, and
# leave the artifact at build/ios/stamped/<landscape>.ipa — the workflow
# uploads it to TestFlight. Runs inside `nix develop .#cd-ios` on macOS
# (codesign). See docs/github-actions-release.md.
#
# Usage: publish-ios.sh <landscape> <donor.ipa>
#
# Env: APP_STORE_CONNECT_* / CERTIFICATE_PRIVATE_KEY (signing),
#      GITHUB_REF_TYPE / GITHUB_REF_NAME (version name on tag builds)

LANDSCAPE=$1 DONOR_IPA=$2

# shellcheck source=scripts/ci/lib-ios.sh disable=SC1091
source "$(dirname "$0")/lib-ios.sh"

keychain initialize
fetch_signing_files "$LANDSCAPE"
keychain add-certificates

mkdir -p build/ios/stamped
./scripts/ci/stamp-ios.sh "$DONOR_IPA" "$LANDSCAPE" \
  "$(build_number_for "$LANDSCAPE")" \
  "build/ios/stamped/$LANDSCAPE.ipa" \
  "$(release_version_name)"
