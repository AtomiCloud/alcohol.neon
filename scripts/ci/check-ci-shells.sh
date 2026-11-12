#!/usr/bin/env bash
set -euo pipefail

# Fails if a CI or CD dev shell pulls atomiutils. It is a 1.3 GB attic-only NAR,
# and on a cold runner its download stalls (HTTP/2 stream errors through
# Cloudflare), which has pushed release, lint and iOS build jobs past their
# timeouts. Only evaluates the flake, so it runs on Linux for the darwin shells.
# Run in the Test job, or locally with `./scripts/ci/check-ci-shells.sh`.

SHELLS="cd-ios build-android publish-ios publish-android ci test releaser"
SYSTEMS="aarch64-darwin x86_64-linux"

failed=0
for system in $SYSTEMS; do
  for shell in $SHELLS; do
    names=$(nix eval --raw ".#devShells.$system.$shell.buildInputs" \
      --apply 'ps: builtins.concatStringsSep " " (map (p: p.pname or p.name) ps)')
    if grep -qw atomiutils <<<"$names"; then
      echo "check-ci-shells: $shell ($system) pulls atomiutils: $names" >&2
      failed=1
    fi
  done
done
[ "$failed" = 0 ] || exit 1
echo "check-ci-shells: ok"
