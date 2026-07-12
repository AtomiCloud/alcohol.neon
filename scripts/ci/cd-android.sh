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

flutter pub get

# The donor carries a placeholder versionCode (each Play app has its own
# sequence — publish jobs stamp the real one) and the tag's version name.
build_args=(--release --flavor raichu --build-number="${GITHUB_RUN_NUMBER:-1}")
if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  build_args+=(--build-name="${GITHUB_REF_NAME#v}")
fi

flutter build appbundle "${build_args[@]}"
