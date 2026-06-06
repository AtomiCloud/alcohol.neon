#!/usr/bin/env bash
#
# Regenerate the zinc Dart DTOs from its OpenAPI spec.
#
# MODELS-ONLY: swagger_parser also emits Retrofit/dio REST clients, but we keep
# our own ApiClient (Result<T>/Problem, lazy bearer), so the generated clients
# are deleted here and dio/retrofit never enter our dependency tree. The DTOs are
# standalone json_serializable classes; build_runner generates their *.g.dart.
#
# Usage: ./scripts/generate-sdk.sh [SPEC_URL]   (run from repo root)
#        or: pls generate:sdk  /  task generate:sdk
set -euo pipefail

SPEC_URL="${1:-https://api.zinc.alcohol.pichu.cluster.atomi.cloud/swagger/v1/swagger.json}"
SPEC_FILE="openapi/zinc.swagger.json"
OUT="lib/generated/zinc"

echo "==> Fetching zinc OpenAPI spec"
echo "    $SPEC_URL"
mkdir -p openapi
if curl -sS -f -m 30 "$SPEC_URL" -o "$SPEC_FILE.tmp"; then
  mv "$SPEC_FILE.tmp" "$SPEC_FILE"
  echo "    updated $SPEC_FILE"
else
  rm -f "$SPEC_FILE.tmp"
  echo "    WARN: fetch failed — falling back to committed $SPEC_FILE"
fi

echo "==> Generating DTOs (swagger_parser)"
rm -rf "$OUT"
flutter pub run swagger_parser

echo "==> Dropping generated REST clients (we use our own ApiClient)"
rm -rf "$OUT/clients"

# The zinc spec's AirwallexEvent declares duplicate snake+camel properties
# (account_id AND accountId, created_at AND createdAt) which collapse to the same
# Dart field and won't compile. These are server-to-server payment-webhook types
# the app never deserializes (nothing we call references them), so prune them.
echo "==> Pruning unused Airwallex webhook models (spec duplicate-property quirk)"
rm -f "$OUT"/models/airwallex_event*.dart

echo "==> Rewriting export barrel (models only)"
{
  echo "// GENERATED — do not edit by hand. Models-only barrel."
  echo "// The Retrofit/dio clients swagger_parser emits are dropped; see scripts/generate-sdk.sh."
  echo "// Regenerate with: pls generate:sdk"
  for f in "$OUT"/models/*.dart; do
    [ -f "$f" ] || continue
    case "$f" in *.g.dart) continue ;; esac
    echo "export 'models/$(basename "$f")';"
  done
} >"$OUT/export.dart"

echo "==> build_runner (json_serializable *.g.dart)"
flutter pub run build_runner build

echo "==> Done. DTOs in $OUT/models, barrel at $OUT/export.dart"
