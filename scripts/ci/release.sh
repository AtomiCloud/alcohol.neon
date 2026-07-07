#!/usr/bin/env bash
set -euo pipefail
rm .git/hooks/* 2>/dev/null || true
# The npm cache action can restore a stale node_modules with no matching
# package.json/lock, which crashes npm's arborist during sg's semantic-release
# install ("Cannot read properties of null (reading 'matches')") — start clean.
rm -rf node_modules package.json package-lock.json
sg release -i npm
