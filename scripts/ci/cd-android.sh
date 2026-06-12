#!/usr/bin/env bash
set -euo pipefail

# Builds + signs one Android flavor into a release AAB. Runs inside `nix develop
# .#cd-android`. See docs/github-actions-release.md.
#
# Env:
#   FLAVOR                                  flutter flavor
#   PACKAGE_NAME                            Play applicationId (for get-latest-build-number)
#   GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS Play publishing service-account JSON
#   ANDROID_KEYSTORE_BASE64                 base64 of the upload keystore (.jks)
#   ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
#   GITHUB_WORKSPACE                        repo root
#   GITHUB_REF_TYPE / GITHUB_REF_NAME       version name = tag (v1.2.3 -> 1.2.3) on a tag build

# key.properties is the existing release-signing path in android/app/build.gradle.kts.
KS="$GITHUB_WORKSPACE/android/app/upload-keystore.jks"
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d >"$KS"
cat >"$GITHUB_WORKSPACE/android/key.properties" <<EOF
storeFile=$KS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
EOF

# GRADLE_USER_HOME is the only properties scope that reaches the flutter_tools included
# build (its KGP 2.0.x has a daemon-startup race, KT-69929 — in-process avoids the daemon
# entirely), and it overrides the project's dev-sized -Xmx8G, which doesn't fit the 8 GB
# runner. Full story: docs/github-actions-release.md.
mkdir -p "$HOME/.gradle"
cat >>"$HOME/.gradle/gradle.properties" <<'EOF'
kotlin.compiler.execution.strategy=in-process
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=320m
EOF

flutter pub get

# versionCode must top every existing Play release (including the prior Codemagic ones),
# or Play rejects the rollout — so query the highest across all tracks and increment.
LATEST=$(google-play get-latest-build-number --package-name "$PACKAGE_NAME" || echo 0)
VERSION_CODE=$((${LATEST:-0} + 1))

# Version name = release tag (v1.2.3 -> 1.2.3). Dropped on non-tag (manual) runs.
build_args=(--release --flavor "$FLAVOR" --build-number="$VERSION_CODE")
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  build_args+=(--build-name="${GITHUB_REF_NAME#v}")
fi

flutter build appbundle "${build_args[@]}"
