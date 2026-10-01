#!/bin/sh
# Picks every line given, four at a time: tools/campaign/pickall.sh 3 4 5 ...
cd "$(dirname "$0")/../.."
npx rolldown tools/campaign/pick.ts --platform node --format esm -o node_modules/.cache/campaign-pick.mjs >/dev/null
printf '%s\n' "$@" | xargs -P 4 -I{} sh -c 'node node_modules/.cache/campaign-pick.mjs {} 4 > tools/campaign/out/log-{}.txt 2>&1'
