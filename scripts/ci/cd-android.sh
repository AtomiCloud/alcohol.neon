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

# The Kotlin compile worker/daemon intermittently dies on the CI runner ("daemon terminated
# unexpectedly on startup … No such file or directory"), failing :compileKotlin
# nondeterministically. Ask Kotlin to run in-process (best effort) — and the build is retried
# below to absorb the flake when the daemon still loses the race.
printf '\nkotlin.compiler.execution.strategy=in-process\norg.gradle.workers.max=1\n' >>"$GITHUB_WORKSPACE/android/gradle.properties"

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

# Retry to absorb the intermittent Kotlin compile-daemon crash (see above).
attempts=3
for attempt in $(seq 1 "$attempts"); do
  if flutter build appbundle "${build_args[@]}"; then
    break
  fi
  if [ "$attempt" -eq "$attempts" ]; then
    echo "appbundle build failed after $attempts attempts" >&2
    exit 1
  fi
  echo "appbundle build attempt $attempt failed; cleaning Kotlin daemon state and retrying…" >&2
  rm -rf "${HOME}/.kotlin/daemon" 2>/dev/null || true
done
