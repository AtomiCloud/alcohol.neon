#!/usr/bin/env bash
set -euo pipefail

# Builds ONE signed iOS release IPA (raichu — the donor; the compiled app is
# landscape-agnostic, see scripts/ci/stamp-ios.sh), then stamps it into each
# requested landscape's IPA. Runs inside `nix develop .#cd-ios`; the build goes
# through scripts/flutter-ios.sh, which un-hijacks the nix C/C++ toolchain so
# xcodebuild uses real Xcode. See docs/github-actions-release.md.
#
# Env:
#   LANDSCAPES                        space-separated landscapes to stamp
#                                     (e.g. "pichu pikachu raichu")
#   APP_STORE_CONNECT_ISSUER_ID       ) ASC API key — read by codemagic-cli-tools by name
#   APP_STORE_CONNECT_KEY_IDENTIFIER  )
#   APP_STORE_CONNECT_PRIVATE_KEY     )
#   CERTIFICATE_PRIVATE_KEY           Apple Distribution cert private key
#   GITHUB_REF_TYPE / GITHUB_REF_NAME version name = tag (v1.2.3 -> 1.2.3) on a tag build
#
# Outputs: build/ios/stamped/<landscape>.ipa per requested landscape.

DONOR=raichu

flutter pub get

(cd ios && pod install)

# Code signing: reuse the existing Apple Distribution cert that matches
# CERTIFICATE_PRIVATE_KEY (--create only mints one if none matches). Signing files
# are fetched for the app AND every embedded extension (widget, …) — the target
# list is discovered from the Xcode project, so new extensions need no CI change.
# --create self-heals missing bundle ids/profiles, but App Group creation and
# group⇄bundle-id association have no API: an App Manager must run `pls register`
# once per new target (see docs/developer/standard/bundle-id.md).
#
# Only the DONOR's profiles are fetched before the build — `use-profiles` maps
# profiles onto the project per config, and keeping the other landscapes'
# profiles off-disk here keeps the proven single-flavor export path untouched.
keychain initialize
fetch_signing_files() {
  local landscape=$1 targets target_id
  # Captured (not a process substitution) so a discovery failure aborts the run
  # instead of being swallowed as an empty loop.
  targets=$(./scripts/ci/ios-signing-targets.sh "$landscape")
  while IFS= read -r target_id; do
    app-store-connect fetch-signing-files "$target_id" \
      --type IOS_APP_STORE \
      --certificate-key @env:CERTIFICATE_PRIVATE_KEY \
      --create
  done <<<"$targets"
  # Doctor: every fetched profile must carry the App Group entitlement — catches
  # a skipped `pls register` here instead of as an opaque xcodebuild/App Store
  # rejection after a 30-minute build.
  ./scripts/ci/doctor-ios.sh "$landscape"
}
fetch_signing_files "$DONOR"
keychain add-certificates
xcode-project use-profiles --export-options-plist "$HOME/export_options.plist"

# CFBundleVersion must top every previous upload for the landscape's ASC app
# record, but get-latest-build-number lags while a fresh upload is still
# processing — max with the CI run number so reruns never collide. apple_id
# comes from lpsm.yaml (filled by `pls register`); while empty, fall back to
# the CI run number alone.
build_number_for() {
  local landscape=$1 apple_id latest n
  apple_id=$(yq ".landscapes[] | select(.name==\"$landscape\") | .apple_id // \"\"" lpsm.yaml)
  latest=0
  if [ -n "$apple_id" ]; then
    latest=$(app-store-connect get-latest-build-number "$apple_id" || echo 0)
  fi
  n=$((${latest:-0} + 1))
  if [ "${GITHUB_RUN_NUMBER:-0}" -gt "$n" ]; then
    n=${GITHUB_RUN_NUMBER}
  fi
  echo "$n"
}

# Version name = release tag; manual runs fall back to pubspec's version.
build_args=(--release --flavor "$DONOR" --build-number="$(build_number_for "$DONOR")"
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

DONOR_IPA=$(find build/ios/ipa -name '*.ipa' | head -1)

# Stamp each requested landscape from the donor. The donor itself ships
# as-built (its ids/name/icons are already correct — re-signing identical
# content would only add risk).
mkdir -p build/ios/stamped
for landscape in $LANDSCAPES; do
  if [ "$landscape" = "$DONOR" ]; then
    cp "$DONOR_IPA" "build/ios/stamped/$landscape.ipa"
    continue
  fi
  fetch_signing_files "$landscape"
  ./scripts/ci/stamp-ios.sh "$DONOR_IPA" "$landscape" \
    "$(build_number_for "$landscape")" "build/ios/stamped/$landscape.ipa"
done
