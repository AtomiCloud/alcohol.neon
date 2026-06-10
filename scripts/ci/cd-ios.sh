#!/usr/bin/env bash
set -euo pipefail

# Builds + signs a single iOS flavor into a release IPA (build/ios/ipa/*.ipa).
# Toolchain (flutter, CocoaPods, GNU rsync, codemagic-cli-tools) is provisioned by the
# workflow; this script owns the imperative build/sign logic so it stays runnable locally:
#
#   FLAVOR=pichu BUNDLE_ID=cloud.atomi.alcohol.neon.pichu APP_STORE_APPLE_ID=6777280038 \
#   APP_STORE_CONNECT_ISSUER_ID=... APP_STORE_CONNECT_KEY_IDENTIFIER=... \
#   APP_STORE_CONNECT_PRIVATE_KEY=... CERTIFICATE_PRIVATE_KEY=... \
#   ./scripts/ci/cd-ios.sh
#
# NOTE: deliberately NOT run inside the nix dev shell — nix hijacks the C/C++ toolchain and
# breaks xcodebuild (see docs/github-actions-release.md "How signing works (no nix)").
#
# Env:
#   FLAVOR                            flutter flavor
#   BUNDLE_ID                         iOS bundle identifier
#   APP_STORE_APPLE_ID                numeric Apple ID (for get-latest-build-number)
#   APP_STORE_CONNECT_ISSUER_ID       ) ASC API key — read by codemagic-cli-tools by name
#   APP_STORE_CONNECT_KEY_IDENTIFIER  )
#   APP_STORE_CONNECT_PRIVATE_KEY     )
#   CERTIFICATE_PRIVATE_KEY           Apple Distribution cert private key
#   GITHUB_REF_TYPE / GITHUB_REF_NAME version name = tag (v1.2.3 -> 1.2.3) on a tag build

flutter pub get

(cd ios && pod install)

# Code signing: reuse the existing Apple Distribution cert that matches
# CERTIFICATE_PRIVATE_KEY (--create only mints one if none matches).
keychain initialize
app-store-connect fetch-signing-files "$BUNDLE_ID" \
  --type IOS_APP_STORE \
  --certificate-key @env:CERTIFICATE_PRIVATE_KEY \
  --create
keychain add-certificates
xcode-project use-profiles --export-options-plist "$HOME/export_options.plist"

# Build number = latest TestFlight build + 1; resilient to the first-ever build (echo 0).
LATEST=$(app-store-connect get-latest-build-number "$APP_STORE_APPLE_ID" || echo 0)
BUILD_NUMBER=$((${LATEST:-0} + 1))

# Version name = release tag (v1.2.3 -> 1.2.3). On non-tag (manual) runs the flag is dropped
# and pubspec's version is used.
build_args=(--release --flavor "$FLAVOR" --build-number="$BUILD_NUMBER"
  --export-options-plist="$HOME/export_options.plist")
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  build_args+=(--build-name="${GITHUB_REF_NAME#v}")
fi

flutter build ipa "${build_args[@]}"
