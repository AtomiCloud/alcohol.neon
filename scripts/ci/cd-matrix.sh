#!/usr/bin/env bash
set -euo pipefail

# Resolves the CD build matrix and prints it as JSON ({"include":[...]}) to stdout.
# All 3 flavors on a tag/push; just the selected flavor on a manual workflow_dispatch.
# The caller wires it to GitHub: matrix=$(./scripts/ci/cd-matrix.sh) >> "$GITHUB_OUTPUT".
#
# Every identifier derives from the LPSM service tree (see
# docs/developer/standard/bundle-id.md): package_name (Android) ==
# cloud.atomi.<landscape>.<platform>.<service>, identical to the iOS bundle id
# (which CD discovers from the Xcode project via ios-signing-targets.sh).
# Only apple_id (the numeric App Store Connect app id) is store-assigned state:
# fill it in after creating each landscape's ASC app record
# (docs/migration-lpsm-ids.md). Empty apple_id → cd-ios.sh falls back to the CI
# run number for CFBundleVersion.
#
# Env:
#   EVENT  github.event_name      (e.g. push, workflow_dispatch)
#   SEL    github.event.inputs.flavor (workflow_dispatch only)
#
# Run locally:
#   EVENT=push ./scripts/ci/cd-matrix.sh
#   EVENT=workflow_dispatch SEL=pichu ./scripts/ci/cd-matrix.sh

PLATFORM=alcohol
SERVICE=neon

# landscape → numeric ASC app id (TODO: fill after the new app records exist).
LANDSCAPES='[
  {"flavor":"pichu","apple_id":""},
  {"flavor":"pikachu","apple_id":""},
  {"flavor":"raichu","apple_id":""}
]'

ALL=$(echo "$LANDSCAPES" | jq -c --arg p "$PLATFORM" --arg s "$SERVICE" \
  '[.[] | . + {package_name: "cloud.atomi.\(.flavor).\($p).\($s)"}]')

if [ "${EVENT:-}" = "workflow_dispatch" ]; then
  FILTERED=$(echo "$ALL" | jq -c --arg f "${SEL:-}" '[.[] | select(.flavor==$f)]')
else
  FILTERED=$(echo "$ALL" | jq -c '.')
fi

echo "{\"include\":$FILTERED}"
