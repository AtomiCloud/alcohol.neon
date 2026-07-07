#!/usr/bin/env bash
set -euo pipefail

# Resolves the CD build matrix and prints it as JSON ({"include":[...]}) to stdout.
# All flavors on a tag/push; just the selected flavor on a manual workflow_dispatch.
# The caller wires it to GitHub: matrix=$(./scripts/ci/cd-matrix.sh) >> "$GITHUB_OUTPUT".
#
# Everything comes from lpsm.yaml — the single source of truth for the LPSM
# service tree (docs/developer/standard/bundle-id.md): package_name (Android)
# == cloud.atomi.<landscape>.<platform>.<service>, identical to the iOS bundle
# id (which CD discovers from the Xcode project via ios-signing-targets.sh).
# apple_id (the numeric App Store Connect app id) is filled into lpsm.yaml by
# `pls register`; while empty, cd-ios.sh falls back to the CI run number for
# CFBundleVersion.
#
# Needs yq (mikefarah v4): preinstalled on GitHub ubuntu runners, in the nix
# dev shell locally.
#
# Env:
#   EVENT  github.event_name      (e.g. push, workflow_dispatch)
#   SEL    github.event.inputs.flavor (workflow_dispatch only)
#
# Run locally:
#   EVENT=push ./scripts/ci/cd-matrix.sh
#   EVENT=workflow_dispatch SEL=pichu ./scripts/ci/cd-matrix.sh

LPSM="$(dirname "$0")/../../lpsm.yaml"

PLATFORM=$(yq '.platform' "$LPSM")
SERVICE=$(yq '.service' "$LPSM")

ALL=$(yq -o=json -I=0 '.landscapes' "$LPSM" | jq -c --arg p "$PLATFORM" --arg s "$SERVICE" \
  '[.[] | {flavor: .name, apple_id: (.apple_id // ""), package_name: "cloud.atomi.\(.name).\($p).\($s).app"}]')

if [ "${EVENT:-}" = "workflow_dispatch" ]; then
  FILTERED=$(echo "$ALL" | jq -c --arg f "${SEL:-}" '[.[] | select(.flavor==$f)]')
else
  FILTERED=$(echo "$ALL" | jq -c '.')
fi

echo "{\"include\":$FILTERED}"
