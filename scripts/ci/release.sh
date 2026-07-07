#!/usr/bin/env bash
set -euo pipefail
rm .git/hooks/* 2>/dev/null || true
# The npm cache action can restore a stale node_modules with no matching
# package.json/lock, which crashes npm's arborist during sg's semantic-release
# install ("Cannot read properties of null (reading 'matches')") — start clean.
# node_modules is a mounted cache volume on the runner ("Device or resource
# busy"), so empty its contents rather than removing the mountpoint.
if [ -d node_modules ]; then find node_modules -mindepth 1 -delete 2>/dev/null || true; fi
rm -f package.json package-lock.json
sg release -i npm
