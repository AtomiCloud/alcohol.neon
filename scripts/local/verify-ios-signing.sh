#!/usr/bin/env bash
set -euo pipefail

# Runs CD's iOS signing preflight LOCALLY: fetch-signing-files for every
# discovered target + the App Group doctor — a seconds-fast loop for
# provisioning/App Group issues instead of a 30-minute GHA round trip.
# Secrets come from Infisical (the org signing project that also feeds the
# GitHub Actions secrets); nothing is written to disk beyond what CD itself
# produces (certs/profiles in your user Library).
#
# Needs: macOS, `infisical login` with access to the signing project, pipx
# (dev shell) for codemagic-cli-tools.
#
# Env:
#   NEON_SIGNING_PROJECT_ID  Infisical project id holding the signing secrets
#   NEON_SIGNING_ENV         Infisical environment slug (default: raichu)
#
# Usage: ./scripts/local/verify-ios-signing.sh <landscape>
#        pls verify:ios -- pichu

L=${1:?usage: verify-ios-signing.sh <landscape>}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

if [ "$(uname)" != "Darwin" ]; then
  echo "✗ macOS only (uses security/plutil for profile decoding)" >&2
  exit 1
fi

export INFISICAL_API_URL="https://secrets.atomi.cloud"

# Re-exec under `infisical run` so the signing secrets (including multiline
# private keys) are injected as env vars with the exact names CD uses.
if [ -z "${APP_STORE_CONNECT_PRIVATE_KEY:-}" ]; then
  : "${NEON_SIGNING_PROJECT_ID:?set NEON_SIGNING_PROJECT_ID to the Infisical signing project id (docs/store-credentials.md)}"
  infisical user get token --silent >/dev/null 2>&1 || infisical login
  exec infisical run --projectId "$NEON_SIGNING_PROJECT_ID" \
    --env "${NEON_SIGNING_ENV:-raichu}" -- "$0" "$@"
fi

if ! command -v app-store-connect >/dev/null; then
  echo "==> installing codemagic-cli-tools via pipx"
  pipx install codemagic-cli-tools
  export PATH="$HOME/.local/bin:$PATH"
fi

cd "$ROOT"
echo "==> fetching signing files for every $L target"
TARGETS=$(./scripts/ci/ios-signing-targets.sh "$L")
while IFS= read -r target_id; do
  app-store-connect fetch-signing-files "$target_id" \
    --type IOS_APP_STORE \
    --certificate-key @env:CERTIFICATE_PRIVATE_KEY \
    --create
done <<<"$TARGETS"

echo "==> doctor"
./scripts/ci/doctor-ios.sh "$L"
