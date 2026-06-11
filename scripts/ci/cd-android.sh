#!/usr/bin/env bash
set -euo pipefail

# Builds + signs a single Android flavor into a release AAB
# (build/app/outputs/bundle/<flavor>Release/*.aab). Runs INSIDE the nix dev shell
# (`nix develop .#cd-android -c ./scripts/ci/cd-android.sh`) so flutter + Android SDK + JDK come
# from the shared nix cache (the shell sets ANDROID_SDK_ROOT/ANDROID_HOME/JAVA_HOME).
# pipx-installed codemagic-cli-tools (google-play) is on PATH via ~/.local/bin:
#
#   nix develop .#cd-android -c env FLAVOR=pichu PACKAGE_NAME=cloud.atomi.alcohol_neon.pichu \
#   GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS="$(cat sa.json)" ANDROID_KEYSTORE_BASE64=... \
#   ANDROID_KEYSTORE_PASSWORD=... ANDROID_KEY_ALIAS=... ANDROID_KEY_PASSWORD=... \
#   GITHUB_WORKSPACE="$PWD" ./scripts/ci/cd-android.sh
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

# Kotlin daemon flake fix (KT-69929/KT-72530): the nixpkgs flutter wrapper compiles
# flutter_tools' Gradle plugin as a synthetic INCLUDED build (~/.cache/flutter/
# nix-flutter-tools-gradle/<engine-rev>) whose kotlin-dsl pulls KGP 2.0.x, which has a
# daemon-startup race that intermittently kills :<engine-rev>:compileKotlin ("daemon has
# terminated unexpectedly … No such file or directory"). Properties in android/
# gradle.properties never reach included builds; GRADLE_USER_HOME properties apply to every
# build in the invocation, so force in-process compilation (no Kotlin daemon at all) here.
# Also right-size the Gradle daemon for this runner: the project's -Xmx8G (fine for dev
# machines) leaves no headroom on the 8 GB CI box, and the Kotlin daemon would inherit it.
mkdir -p "$HOME/.gradle"
cat >>"$HOME/.gradle/gradle.properties" <<'EOF'
kotlin.compiler.execution.strategy=in-process
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=320m
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
