#!/usr/bin/env bash
set -euo pipefail

# Builds + signs a single Android flavor into a release AAB
# (build/app/outputs/bundle/<flavor>Release/*.aab). Toolchain (JDK, flutter, Android SDK,
# codemagic-cli-tools) is provisioned by the workflow; this script owns the build/sign logic
# so it stays runnable locally:
#
#   FLAVOR=pichu PACKAGE_NAME=cloud.atomi.alcohol_neon.pichu \
#   GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS="$(cat sa.json)" \
#   ANDROID_KEYSTORE_BASE64=... ANDROID_KEYSTORE_PASSWORD=... \
#   ANDROID_KEY_ALIAS=... ANDROID_KEY_PASSWORD=... GITHUB_WORKSPACE="$PWD" \
#   ./scripts/ci/cd-android.sh
#
# Env:
#   FLAVOR                                  flutter flavor
#   PACKAGE_NAME                            Play applicationId (for get-latest-build-number)
#   GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS Play publishing service-account JSON
#   ANDROID_KEYSTORE_BASE64                 base64 of the upload keystore (.jks)
#   ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
#   GITHUB_WORKSPACE                        repo root
#   GITHUB_REF_TYPE / GITHUB_REF_NAME       version name = tag (v1.2.3 -> 1.2.3) on a tag build

# Decode the upload keystore + write key.properties (consumed by the existing path in
# android/app/build.gradle.kts).
KS="$GITHUB_WORKSPACE/android/app/upload-keystore.jks"
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d >"$KS"
cat >"$GITHUB_WORKSPACE/android/key.properties" <<EOF
storeFile=$KS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
EOF

flutter pub get

# versionCode = highest existing Play build number (across all tracks) + 1. Mirrors the iOS
# build-number logic and coordinates with releases from the prior (Codemagic) pipeline — a bare
# monotonic counter (e.g. run_number) can land below an existing release and Play then rejects the
# rollout with "does not allow any existing users to upgrade to the newly added APKs".
LATEST=$(google-play get-latest-build-number --package-name "$PACKAGE_NAME" || echo 0)
VERSION_CODE=$((${LATEST:-0} + 1))

# Version name = release tag (v1.2.3 -> 1.2.3). Dropped on non-tag (manual) runs.
build_args=(--release --flavor "$FLAVOR" --build-number="$VERSION_CODE")
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  build_args+=(--build-name="${GITHUB_REF_NAME#v}")
fi

flutter build appbundle "${build_args[@]}"
