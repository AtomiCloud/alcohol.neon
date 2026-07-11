#!/usr/bin/env bash
set -euo pipefail

# Builds the donor IPA — one signed raichu Release build whose compiled payload
# is landscape-agnostic (bundle-id-as-marker); the per-landscape publish jobs
# re-badge it via scripts/ci/publish-ios.sh. Runs inside `nix develop .#cd-ios`;
# the build goes through scripts/flutter-ios.sh, which un-hijacks the nix C/C++
# toolchain so xcodebuild uses real Xcode. See docs/github-actions-release.md.
#
# Env:
#   APP_STORE_CONNECT_ISSUER_ID       ) ASC API key — read by codemagic-cli-tools by name
#   APP_STORE_CONNECT_KEY_IDENTIFIER  )
#   APP_STORE_CONNECT_PRIVATE_KEY     )
#   CERTIFICATE_PRIVATE_KEY           Apple Distribution cert private key
#   GITHUB_REF_TYPE / GITHUB_REF_NAME version name = tag (v1.2.3 -> 1.2.3) on a tag build
#
# Output: build/ios/ipa/*.ipa

DONOR=raichu

# shellcheck source=scripts/ci/lib-ios.sh disable=SC1091
source "$(dirname "$0")/lib-ios.sh"

flutter pub get

(cd ios && pod install)

# Only the donor's profiles are fetched here — `use-profiles` maps profiles
# onto the project per config, and keeping other landscapes' profiles off-disk
# keeps the single-flavor export deterministic. Publish jobs fetch their own.
keychain initialize
fetch_signing_files "$DONOR"
keychain add-certificates
xcode-project use-profiles --export-options-plist "$HOME/export_options.plist"

# The donor carries raichu's real build number and the tag's version name; the
# publish jobs re-stamp both per landscape anyway (each ASC record has its own
# build-number sequence).
build_args=(--release --flavor "$DONOR" --build-number="$(build_number_for "$DONOR")"
--export-options-plist="$HOME/export_options.plist")
VERSION_NAME=$(release_version_name)
if [ -n "$VERSION_NAME" ]; then
  build_args+=(--build-name="$VERSION_NAME")
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
  ls build/ios/ipa/*.ipa >/dev/null 2>&1 || {
    echo "re-export reported success but produced no IPA" >&2
    exit 1
  }
else
  echo "iOS archive was not produced (rc=$build_rc)" >&2
  exit "${build_rc:-1}"
fi
