#!/usr/bin/env bash
set -euo pipefail

# Builds ONE Android release AAB (raichu — the artifact is landscape-agnostic
# apart from packaging, see scripts/ci/stamp-android.sh), then stamps it into
# each requested landscape's release AAB. Runs inside `nix develop .#cd-android`.
# See docs/github-actions-release.md.
#
# Env:
#   LANDSCAPES                              space-separated landscapes to stamp
#                                           (e.g. "pichu pikachu raichu")
#   GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS Play publishing service-account JSON
#   ANDROID_KEYSTORE_BASE64                 base64 of the upload keystore (.jks)
#   ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
#   GITHUB_WORKSPACE                        repo root
#   GITHUB_REF_TYPE / GITHUB_REF_NAME       version name = tag (v1.2.3 -> 1.2.3) on a tag build
#
# Outputs: build/app/outputs/stamped/<landscape>.aab per landscape.

# key.properties is the existing release-signing path in android/app/build.gradle.kts.
KS="$GITHUB_WORKSPACE/android/app/upload-keystore.jks"
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d >"$KS"
cat >"$GITHUB_WORKSPACE/android/key.properties" <<EOF
storeFile=$KS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
EOF
export ANDROID_KEYSTORE_PATH="$KS"

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

# Version name = release tag (v1.2.3 -> 1.2.3). Dropped on non-tag (manual) runs.
# The build's versionCode is a placeholder — stamping sets the real one per
# landscape (each Play app has its own sequence).
build_args=(--release --flavor raichu --build-number="${GITHUB_RUN_NUMBER:-1}")
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  build_args+=(--build-name="${GITHUB_REF_NAME#v}")
fi

flutter build appbundle "${build_args[@]}"
AAB="build/app/outputs/bundle/raichuRelease/app-raichu-release.aab"

# Stamp each landscape. versionCode must top every existing Play release for
# that package (including the prior Codemagic ones), or Play rejects the
# rollout — query the highest across all tracks and increment. The query can
# miss draft releases on a brand-new app (first uploads), which would recompute
# an already-used code — floor it with the CI run number, which only ever grows
# (same guard as iOS).
PLATFORM=$(yq '.platform' "$GITHUB_WORKSPACE/lpsm.yaml")
SERVICE=$(yq '.service' "$GITHUB_WORKSPACE/lpsm.yaml")
mkdir -p build/app/outputs/stamped
for landscape in $LANDSCAPES; do
  package="cloud.atomi.$landscape.$PLATFORM.$SERVICE.app"
  LATEST=$(google-play get-latest-build-number --package-name "$package" || echo 0)
  VERSION_CODE=$((${LATEST:-0} + 1))
  RUN_NUMBER=${GITHUB_RUN_NUMBER:-0}
  if [ "$RUN_NUMBER" -gt "$VERSION_CODE" ]; then
    VERSION_CODE=$RUN_NUMBER
  fi
  ./scripts/ci/stamp-android.sh "$AAB" "$landscape" "$VERSION_CODE" \
    "build/app/outputs/stamped/$landscape.aab"
done
