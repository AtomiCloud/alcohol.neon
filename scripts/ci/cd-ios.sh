#!/usr/bin/env bash
set -euo pipefail

# Builds + signs one iOS flavor into a release IPA. Runs inside `nix develop .#cd-ios`;
# the build itself goes through scripts/flutter-ios.sh, which un-hijacks the nix C/C++
# toolchain so xcodebuild uses real Xcode. See docs/github-actions-release.md.
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
# CERTIFICATE_PRIVATE_KEY (--create only mints one if none matches). Signing files
# are fetched for the app AND every embedded extension (widget, …) — the target
# list is discovered from the Xcode project, so new extensions need no CI change.
# --create self-heals missing bundle ids/profiles, but App Group creation and
# group⇄bundle-id association have no API: an App Manager must run `pls register`
# once per new target (see docs/developer/standard/bundle-id.md).
keychain initialize
while IFS= read -r target_id; do
  app-store-connect fetch-signing-files "$target_id" \
    --type IOS_APP_STORE \
    --certificate-key @env:CERTIFICATE_PRIVATE_KEY \
    --create
done < <(./scripts/ci/ios-signing-targets.sh "$FLAVOR")
keychain add-certificates
xcode-project use-profiles --export-options-plist "$HOME/export_options.plist"

# Doctor: every fetched profile must carry the App Group entitlement — catches a
# skipped `pls register` here, at the signing step, instead of as an opaque
# xcodebuild/App Store rejection after a 30-minute build.
./scripts/ci/doctor-ios.sh "$FLAVOR"

# CFBundleVersion must top every previous upload, but get-latest-build-number lags while a
# fresh upload is still processing — max with the CI run number so reruns never collide.
# APP_STORE_APPLE_ID is empty until the landscape's ASC app record exists
# (docs/migration-lpsm-ids.md) — fall back to the CI run number alone.
LATEST=0
if [ -n "${APP_STORE_APPLE_ID:-}" ]; then
  LATEST=$(app-store-connect get-latest-build-number "$APP_STORE_APPLE_ID" || echo 0)
fi
BUILD_NUMBER=$((${LATEST:-0} + 1))
RUN_NUMBER=${GITHUB_RUN_NUMBER:-0}
if [ "$RUN_NUMBER" -gt "$BUILD_NUMBER" ]; then
  BUILD_NUMBER=$RUN_NUMBER
fi

# Version name = release tag; manual runs fall back to pubspec's version.
build_args=(--release --flavor "$FLAVOR" --build-number="$BUILD_NUMBER"
  --export-options-plist="$HOME/export_options.plist")
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  build_args+=(--build-name="${GITHUB_REF_NAME#v}")
fi

# The archive needs nix's GNU rsync (openrsync ignores --chmod → lipo fails), but
# xcodebuild's export needs Apple's rsync — so let flutter's export fail and re-export
# the archive with Apple's toolchain below.
set +e
./scripts/flutter-ios.sh build ipa "${build_args[@]}"
build_rc=$?
set -e

if ls build/ios/ipa/*.ipa >/dev/null 2>&1; then
  echo "IPA produced by flutter build ipa."
elif [ -d build/ios/archive/Runner.xcarchive ]; then
  echo "flutter export step failed (rc=$build_rc); re-exporting archive with Apple's toolchain…"
  # Strip nix toolchain vars, /usr/bin first (mirrors scripts/flutter-ios.sh).
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
