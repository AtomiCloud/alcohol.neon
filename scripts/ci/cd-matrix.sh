#!/usr/bin/env bash
set -euo pipefail

# Resolves the CD build matrix and prints it as JSON ({"include":[...]}) to stdout.
# All 3 flavors on a tag/push; just the selected flavor on a manual workflow_dispatch.
# The caller wires it to GitHub: matrix=$(./scripts/ci/cd-matrix.sh) >> "$GITHUB_OUTPUT".
#
# Env:
#   EVENT  github.event_name      (e.g. push, workflow_dispatch)
#   SEL    github.event.inputs.flavor (workflow_dispatch only)
#
# Run locally:
#   EVENT=push ./scripts/ci/cd-matrix.sh
#   EVENT=workflow_dispatch SEL=pichu ./scripts/ci/cd-matrix.sh

ALL='[
  {"flavor":"pichu","bundle_id":"cloud.atomi.alcohol.neon.pichu","apple_id":"6777280038","package_name":"cloud.atomi.alcohol_neon.pichu"},
  {"flavor":"pikachu","bundle_id":"cloud.atomi.alcohol.neon.pikachu","apple_id":"6777280047","package_name":"cloud.atomi.alcohol_neon.pikachu"},
  {"flavor":"raichu","bundle_id":"cloud.atomi.alcohol.neon.raichu","apple_id":"6777280099","package_name":"cloud.atomi.alcohol_neon.raichu"}
]'

if [ "${EVENT:-}" = "workflow_dispatch" ]; then
  FILTERED=$(echo "$ALL" | jq -c --arg f "${SEL:-}" '[.[] | select(.flavor==$f)]')
else
  FILTERED=$(echo "$ALL" | jq -c '.')
fi

echo "{\"include\":$FILTERED}"
