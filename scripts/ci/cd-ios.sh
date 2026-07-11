#!/usr/bin/env bash
set -euo pipefail

# iOS half of the build-once/stamp-per-landscape CD model (see
# scripts/ci/stamp-ios.sh). Three modes, driven by env:
#
#   BUILD_ONLY=1   build the signed donor IPA and stop (CI donor job — iOS
#                  needs the signing secrets even to export, unlike Android)
#   DONOR_IPA=...  skip the build and stamp from this IPA (CD found a CI donor
#                  for the tagged commit); every landscape is stamped,
#                  including raichu — the donor's version fields are
#                  placeholders
#   (neither)      build + stamp — the self-contained fallback; raichu ships
#                  as-built (the build already carries its real numbers)
#
# Runs inside `nix develop .#cd-ios`; builds go through scripts/flutter-ios.sh,
# which un-hijacks the nix C/C++ toolchain so xcodebuild uses real Xcode.
# See docs/github-actions-release.md.
#
# Env:
#   LANDSCAPES                        space-separated landscapes to stamp
#   APP_STORE_CONNECT_ISSUER_ID       ) ASC API key — read by codemagic-cli-tools by name
#   APP_STORE_CONNECT_KEY_IDENTIFIER  )
#   APP_STORE_CONNECT_PRIVATE_KEY     )
#   CERTIFICATE_PRIVATE_KEY           Apple Distribution cert private key
#   GITHUB_REF_TYPE / GITHUB_REF_NAME version name = tag (v1.2.3 -> 1.2.3) on a tag build
#
# Outputs: build/ios/stamped/<landscape>.ipa per requested landscape (stamp
#          modes), build/ios/ipa/*.ipa (BUILD_ONLY).

DONOR=raichu

# Code signing: reuse the existing Apple Distribution cert that matches
# CERTIFICATE_PRIVATE_KEY (--create only mints one if none matches). Signing files
# are fetched for the app AND every embedded extension (widget, …) — the target
# list is discovered from the Xcode project, so new extensions need no CI change.
# --create self-heals missing bundle ids/profiles, but App Group creation and
# group⇄bundle-id association have no API: an App Manager must run `pls register`
# once per new target (see docs/developer/standard/bundle-id.md).
keychain initialize
CERTS_ADDED=0
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

# Version name = release tag; empty keeps the donor's (manual/smoke runs).
VERSION_NAME=""
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  VERSION_NAME="${GITHUB_REF_NAME#v}"
fi

if [ -z "${DONOR_IPA:-}" ]; then
  flutter pub get
  (cd ios && pod install)

  # Only the DONOR's profiles are fetched before the build — `use-profiles` maps
  # profiles onto the project per config, and keeping the other landscapes'
  # profiles off-disk here keeps the proven single-flavor export path untouched.
  fetch_signing_files "$DONOR"
  keychain add-certificates
  CERTS_ADDED=1
  xcode-project use-profiles --export-options-plist "$HOME/export_options.plist"

  build_args=(--release --flavor "$DONOR" --build-number="$(build_number_for "$DONOR")"
  --export-options-plist="$HOME/export_options.plist")
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
  else
    echo "iOS archive was not produced (rc=$build_rc)" >&2
    exit "${build_rc:-1}"
  fi

  SRC_IPA=$(find build/ios/ipa -name '*.ipa' | head -1)

  if [ "${BUILD_ONLY:-}" = "1" ]; then
    echo "cd-ios: donor built ($SRC_IPA) — BUILD_ONLY, skipping stamps."
    exit 0
  fi
  # Fallback build: the donor was built with raichu's real build number and
  # version name, so raichu ships as-built below.
  STAMP_DONOR=0
else
  SRC_IPA="$DONOR_IPA"
  echo "cd-ios: stamping from CI donor $SRC_IPA"
  # CI donors carry placeholder version fields — raichu must be stamped too.
  STAMP_DONOR=1
fi

# Stamp each requested landscape from the donor.
mkdir -p build/ios/stamped
for landscape in $LANDSCAPES; do
  if [ "$landscape" = "$DONOR" ] && [ "$STAMP_DONOR" != "1" ]; then
    cp "$SRC_IPA" "build/ios/stamped/$landscape.ipa"
    continue
  fi
  fetch_signing_files "$landscape"
  # add-certificates needs the cert files fetch-signing-files just downloaded;
  # in donor mode nothing fetched before this loop, so add them on first pass.
  if [ "$CERTS_ADDED" = "0" ]; then
    keychain add-certificates
    CERTS_ADDED=1
  fi
  ./scripts/ci/stamp-ios.sh "$SRC_IPA" "$landscape" \
    "$(build_number_for "$landscape")" "build/ios/stamped/$landscape.ipa" "$VERSION_NAME"
done
