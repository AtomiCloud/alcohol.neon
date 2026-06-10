#!/usr/bin/env bash
set -euo pipefail

# Builds + signs a single iOS flavor into a release IPA (build/ios/ipa/*.ipa).
# Runs INSIDE the nix dev shell (`nix develop .#cd-ios -c ./scripts/ci/cd-ios.sh`) so the
# toolchain (flutter, CocoaPods, GNU rsync, pipx) comes from the shared nix cache. pipx-installed
# codemagic-cli-tools (keychain/app-store-connect/xcode-project) are on PATH via ~/.local/bin:
#
#   nix develop .#cd-ios -c env FLAVOR=pichu BUNDLE_ID=cloud.atomi.alcohol.neon.pichu \
#   APP_STORE_APPLE_ID=6777280038 APP_STORE_CONNECT_ISSUER_ID=... ... ./scripts/ci/cd-ios.sh
#
# NOTE: nix exports a C/C++ stdenv that hijacks xcodebuild, so the actual `flutter build ipa`
# goes through scripts/flutter-ios.sh, which strips the nix toolchain vars and points
# DEVELOPER_DIR at real Xcode. pub get / pod install / the codemagic signing calls don't drive
# clang/ld, so they run directly.
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

# Build through the wrapper (not raw `flutter`) so xcodebuild gets Apple's toolchain, not nix's.
#
# Split archive from export: the archive build needs nix's GNU rsync (macOS openrsync ignores
# --chmod, so nix's read-only Flutter.framework stays read-only → lipo fails), but
# xcodebuild's *export* step fails with "exportArchive Copy failed" when GNU rsync shadows
# Apple's rsync. So let flutter build the archive (GNU rsync on PATH), then re-export the
# archive ourselves with Apple's rsync (/usr/bin first) if flutter's own export didn't produce
# an IPA.
set +e
./scripts/flutter-ios.sh build ipa "${build_args[@]}"
build_rc=$?
set -e

if ls build/ios/ipa/*.ipa >/dev/null 2>&1; then
  echo "IPA produced by flutter build ipa."
elif [ -d build/ios/archive/Runner.xcarchive ]; then
  echo "flutter export step failed (rc=$build_rc); re-exporting archive with Apple's toolchain…"
  # Strip the nix C/C++ toolchain vars and put /usr/bin first so xcodebuild's export uses
  # Apple's rsync + clang (mirrors scripts/flutter-ios.sh's scrubbing).
  while IFS= read -r v; do unset "$v"; done < <(env | sed -n 's/^\(NIX_[A-Za-z0-9_]*\)=.*/\1/p')
  unset CC CXX LD AR NM RANLIB OBJCOPY OBJDUMP STRIP CPP CXXCPP \
    SDKROOT MACOSX_DEPLOYMENT_TARGET LIBRARY_PATH DYLD_LIBRARY_PATH \
    CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH
  export DEVELOPER_DIR="${DEVELOPER_DIR_OVERRIDE:-/Applications/Xcode.app/Contents/Developer}"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
  xcodebuild -exportArchive \
    -archivePath build/ios/archive/Runner.xcarchive \
    -exportPath build/ios/ipa \
    -exportOptionsPlist "$HOME/export_options.plist"
else
  echo "iOS archive was not produced (rc=$build_rc)" >&2
  exit "${build_rc:-1}"
fi
