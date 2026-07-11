#!/usr/bin/env bash
set -euo pipefail

# Shared iOS CD helpers — sourced by cd-ios.sh (build) and publish-ios.sh
# (stamp + upload). Requires codemagic-cli-tools + yq (nix cd-ios shell) and
# the APP_STORE_CONNECT_* / CERTIFICATE_PRIVATE_KEY env.

# Fetch cert + App Store profiles for every signing target of one landscape
# (app + all extensions, discovered from the Xcode project), then doctor them.
# --create self-heals missing bundle ids/profiles, but App Group creation and
# group⇄bundle-id association have no API: an App Manager must run `pls
# register` once per new target (see docs/developer/standard/bundle-id.md).
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
  # rejection after the build.
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

# Version name = release tag (v1.2.3 -> 1.2.3); empty on non-tag (manual) runs.
release_version_name() {
  if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
    echo "${GITHUB_REF_NAME#v}"
  fi
}
