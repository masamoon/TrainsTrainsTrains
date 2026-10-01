#!/bin/sh
# Bundles and runs a campaign tool: tools/campaign/run.sh check [args]
set -e
cd "$(dirname "$0")/../.."
npx rolldown "tools/campaign/$1.ts" --platform node --format esm -o "node_modules/.cache/campaign-$1.mjs" >/dev/null
shift_name=$1; shift
node "node_modules/.cache/campaign-$shift_name.mjs" "$@"
