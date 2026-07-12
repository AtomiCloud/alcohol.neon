#!/usr/bin/env bash
set -euo pipefail

# Builds the donor AAB — one raichu release build whose compiled payload is
# landscape-agnostic (bundle-id-as-marker); the per-landscape publish jobs
# re-badge it via scripts/ci/publish-android.sh. Debug-signed on purpose: this
# job holds no secrets, and stamping re-signs with the upload key. Runs inside
# `nix develop .#cd-android`. See docs/github-actions-release.md.
#
# Env:
#   GITHUB_REF_TYPE / GITHUB_REF_NAME version name = tag (v1.2.3 -> 1.2.3) on a tag build
#
# Output: build/app/outputs/bundle/raichuRelease/*.aab (+ R8 mapping)

# GRADLE_USER_HOME is the only properties scope that reaches the flutter_tools included
# build (its KGP 2.0.x has a daemon-startup race, KT-69929 — in-process avoids the daemon
# entirely), and it overrides the project's dev-sized -Xmx8G, which doesn't fit the 8 GB
# runner. Full story: docs/github-actions-release.md.
mkdir -p "$HOME/.gradle"
if ! grep -q "kotlin.compiler.execution.strategy" "$HOME/.gradle/gradle.properties" 2>/dev/null; then
  cat >>"$HOME/.gradle/gradle.properties" <<'EOF'
kotlin.compiler.execution.strategy=in-process
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=320m
EOF
fi
if ! grep -q "org.gradle.caching" "$HOME/.gradle/gradle.properties" 2>/dev/null; then
  echo "org.gradle.caching=true" >>"$HOME/.gradle/gradle.properties"
fi

# Remote Gradle build cache (Namespace): shared across ALL refs, unlike cache
# volumes, which fork per git ref from the default branch — tag-triggered
# releases always forked a cold base, so task outputs never reused. nsc is
# preinstalled on Namespace runners with ambient auth; degrade gracefully
# anywhere else.
if command -v nsc >/dev/null 2>&1; then
  mkdir -p "$HOME/.gradle/init.d"
  nsc cache gradle setup --init-gradle "$HOME/.gradle/init.d/nsc-remote-cache.gradle" ||
    echo "nsc gradle cache setup failed — building without the remote cache"
fi

flutter pub get

# The donor's version fields are placeholders that stamping replaces per
# landscape — build with constants so the manifest → resources → R8 task
# chain stays release-invariant and the Gradle build cache hits across
# releases (varying versionName re-keyed it all).
flutter build appbundle --release --flavor raichu --build-number=1 --build-name=1.0.0
