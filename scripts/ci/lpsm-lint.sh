#!/usr/bin/env bash
set -euo pipefail

# Lints every hardcoded store identifier against the LPSM service tree
# (lpsm.yaml) — the single source of truth. Xcode/Gradle/pubspec must carry
# literal ids, so instead of generating them this catches drift the moment a
# target, flavor, or config disagrees with the tree.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LPSM="$ROOT/lpsm.yaml"
PBXPROJ="$ROOT/ios/Runner.xcodeproj/project.pbxproj"

if ! command -v yq >/dev/null; then
  echo "lpsm-lint: yq not found — run inside the dev shell (direnv / nix develop)" >&2
  exit 1
fi

P=$(yq '.platform' "$LPSM")
S=$(yq '.service' "$LPSM")
release_landscapes=$(yq '.landscapes[].name' "$LPSM")
# lapras = the local/flavorless landscape: valid in build files, never released.
landscapes="$release_landscapes"$'\n'"lapras"

fail=0
err() {
  echo "lpsm-lint: $1" >&2
  fail=1
}

# id → 0 if it matches cloud.atomi.<L>.<platform>.<service>.<module>[.<module>]*
# for a known L. The module segment is MANDATORY (the main app is the `app`
# module); a module-less id is a grammar violation.
allowed() {
  local id=$1 l
  while IFS= read -r l; do
    [[ $id =~ ^cloud\.atomi\.$l\.$P\.$S(\.[a-z][a-z0-9]*)+$ ]] && return 0
  done <<<"$landscapes"
  return 1
}

# 1. Xcode: every bundle id and app group must derive from the tree.
while IFS= read -r id; do
  allowed "$id" ||
    err "project.pbxproj: PRODUCT_BUNDLE_IDENTIFIER '$id' does not derive from lpsm.yaml ($P/$S)"
done < <(sed -n 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = \([^;]*\);$/\1/p' "$PBXPROJ" | sort -u)

while IFS= read -r grp; do
  case $grp in group.*) ;; *) err "project.pbxproj: NEON_APP_GROUP '$grp' lacks the group. prefix" && continue ;; esac
  allowed "${grp#group.}" ||
    err "project.pbxproj: NEON_APP_GROUP '$grp' is not group.<lpsm app id>"
done < <(sed -n 's/^[[:space:]]*NEON_APP_GROUP = \([^;]*\);$/\1/p' "$PBXPROJ" | sort -u)

# 2. Android applicationIds.
while IFS= read -r id; do
  allowed "$id" ||
    err "build.gradle.kts: applicationId '$id' does not derive from lpsm.yaml"
done < <(sed -n 's/.*applicationId = "\([^"]*\)".*/\1/p' "$ROOT/android/app/build.gradle.kts" | sort -u)

# 3. pubspec flavorizr ids (iOS + Android must both match the tree).
while IFS= read -r id; do
  allowed "$id" ||
    err "pubspec.yaml: flavorizr id '$id' does not derive from lpsm.yaml"
done < <(sed -n "s/.*\(bundleId\|applicationId\): '\([^']*\)'.*/\2/p" "$ROOT/pubspec.yaml" | sort -u)

# 4. Runtime config: each landscape's Logto redirect is <app id>://callback.
while IFS= read -r l; do
  f="$ROOT/config/$l.yaml"
  [ "$l" = lapras ] && f="$ROOT/config/base.yaml"
  [ -f "$f" ] || continue
  want="cloud.atomi.$l.$P.$S.app://callback"
  got=$(sed -n "s/^redirectUri: '\(.*\)'$/\1/p" "$f")
  [ -z "$got" ] || [ "$got" = "$want" ] ||
    err "$(basename "$f"): redirectUri '$got' should be '$want'"
done <<<"$landscapes"

# 5. Every release landscape must actually have an app target in Xcode.
while IFS= read -r l; do
  grep -q "PRODUCT_BUNDLE_IDENTIFIER = cloud\.atomi\.$l\.$P\.$S\.app;" "$PBXPROJ" ||
    err "lpsm.yaml landscape '$l' has no app target in the Xcode project"
done <<<"$release_landscapes"

if [ "$fail" -eq 0 ]; then
  echo "lpsm-lint: OK — all store identifiers derive from lpsm.yaml"
fi
exit "$fail"
