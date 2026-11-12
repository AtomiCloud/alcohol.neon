#!/usr/bin/env bash
set -euo pipefail

# JVM unit tests for the Android widgets (android/app/src/test). Run in CI via
# `nix develop .#build-android -c ./scripts/ci/test-android.sh`, or locally with
# `pls test:android`.

# CI only: the same Gradle sizing as cd-android.sh, for the 8 GB runner (the
# project's dev-sized -Xmx8G doesn't fit it). Locally, leave ~/.gradle alone.
if [ -n "${CI:-}" ]; then
  mkdir -p "$HOME/.gradle"
  if ! grep -q "kotlin.compiler.execution.strategy" "$HOME/.gradle/gradle.properties" 2>/dev/null; then
    cat >>"$HOME/.gradle/gradle.properties" <<'EOF'
kotlin.compiler.execution.strategy=in-process
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=320m
EOF
  fi
fi

# A fresh checkout has neither the Gradle wrapper (Flutter's template gitignores
# it; flutter build injects it) nor android/local.properties (flutter.sdk, which
# settings.gradle.kts reads). --config-only writes both without building.
flutter build apk --config-only --debug --flavor pichu

# nixpkgs' Flutter keeps its Gradle plugin in the read-only Nix store, so Gradle
# needs a writable project cache dir (flutter build passes one too); without it
# ./gradlew exits 1 without printing an error.
cd android
./gradlew --project-cache-dir=../build/gradle-project-cache :app:testPichuDebugUnitTest
