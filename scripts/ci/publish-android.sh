#!/usr/bin/env bash
set -euo pipefail

# Stamps the donor AAB into ONE landscape's release AAB (scripts/ci/
# stamp-android.sh): re-badge, set versionCode/versionName, re-sign with the
# upload key, and leave the artifact at build/app/outputs/stamped/<landscape>.aab
# — the workflow uploads it to the Play internal track. Runs inside
# `nix develop .#cd-android`. See docs/github-actions-release.md.
#
# Usage: publish-android.sh <landscape> <donor.aab>
#
# Env:
#   ANDROID_KEYSTORE_BASE64                 base64 of the upload keystore (.jks)
#   ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
#   GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS Play SA JSON (versionCode query)
#   GITHUB_REF_TYPE / GITHUB_REF_NAME       version name on tag builds

LANDSCAPE=$1 DONOR_AAB=$2

# The donor is debug-signed (its build job holds no secrets) — stamping
# re-signs with the upload key from here.
KS=$(mktemp -d)/upload-keystore.jks
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d >"$KS"
export ANDROID_KEYSTORE_PATH="$KS"

# versionCode must top every existing Play release for this package, or Play
# rejects the rollout — query the highest across all tracks and increment. The
# query can miss draft releases on a brand-new app (first uploads) — floor it
# with the CI run number, which only ever grows (same guard as iOS).
PLATFORM=$(yq '.platform' lpsm.yaml)
SERVICE=$(yq '.service' lpsm.yaml)
PACKAGE="cloud.atomi.$LANDSCAPE.$PLATFORM.$SERVICE.app"
LATEST=$(google-play get-latest-build-number --package-name "$PACKAGE" || echo 0)
VERSION_CODE=$((${LATEST:-0} + 1))
if [ "${GITHUB_RUN_NUMBER:-0}" -gt "$VERSION_CODE" ]; then
  VERSION_CODE=${GITHUB_RUN_NUMBER}
fi

VERSION_NAME=""
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  VERSION_NAME="${GITHUB_REF_NAME#v}"
fi

mkdir -p build/app/outputs/stamped
./scripts/ci/stamp-android.sh "$DONOR_AAB" "$LANDSCAPE" "$VERSION_CODE" \
  "build/app/outputs/stamped/$LANDSCAPE.aab" "$VERSION_NAME"
