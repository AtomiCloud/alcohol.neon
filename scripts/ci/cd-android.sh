#!/usr/bin/env bash
set -euo pipefail

# Android half of the build-once/stamp-per-landscape CD model (see
# scripts/ci/stamp-android.sh). Three modes, driven by env:
#
#   BUILD_ONLY=1   build the donor AAB and stop (CI donor job — needs no
#                  signing secrets; the donor is debug-signed and every
#                  landscape is re-signed at stamp time anyway)
#   DONOR_AAB=...  skip the build and stamp from this AAB (CD found a CI donor
#                  for the tagged commit)
#   (neither)      build + stamp — the self-contained fallback
#
# Runs inside `nix develop .#cd-android`. See docs/github-actions-release.md.
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
# Outputs: build/app/outputs/stamped/<landscape>.aab per landscape (stamp modes),
#          build/app/outputs/bundle/raichuRelease/*.aab (BUILD_ONLY).

# key.properties is the existing release-signing path in android/app/build.gradle.kts.
# Skipped when no keystore is provided (BUILD_ONLY in CI) — gradle then
# debug-signs the donor, which stamping re-signs with the upload key later.
if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
  KS="$GITHUB_WORKSPACE/android/app/upload-keystore.jks"
  echo "$ANDROID_KEYSTORE_BASE64" | base64 -d >"$KS"
  cat >"$GITHUB_WORKSPACE/android/key.properties" <<EOF
storeFile=$KS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
EOF
  export ANDROID_KEYSTORE_PATH="$KS"
fi

if [ -z "${DONOR_AAB:-}" ]; then
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

  # The donor's versionCode/versionName are placeholders — stamping sets the
  # real ones per landscape (version name from the tag, code per Play app).
  build_args=(--release --flavor raichu --build-number="${GITHUB_RUN_NUMBER:-1}")
  if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
    build_args+=(--build-name="${GITHUB_REF_NAME#v}")
  fi

  flutter build appbundle "${build_args[@]}"
  AAB="build/app/outputs/bundle/raichuRelease/app-raichu-release.aab"

  if [ "${BUILD_ONLY:-}" = "1" ]; then
    echo "cd-android: donor built ($AAB) — BUILD_ONLY, skipping stamps."
    exit 0
  fi
else
  AAB="$DONOR_AAB"
  echo "cd-android: stamping from CI donor $AAB"
fi

# Version name = release tag (v1.2.3 -> 1.2.3); empty keeps the donor's
# (manual/smoke runs). Stamped into every landscape — CI donors are built
# before the tag exists.
VERSION_NAME=""
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  VERSION_NAME="${GITHUB_REF_NAME#v}"
fi

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
    "build/app/outputs/stamped/$landscape.aab" "$VERSION_NAME"
done
