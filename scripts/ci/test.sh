#!/usr/bin/env bash
set -euo pipefail

# Flutter unit tests. Run in CI via `nix develop .#ci -c ./scripts/ci/test.sh`,
# or locally with `pls test`.
flutter pub get
flutter test
