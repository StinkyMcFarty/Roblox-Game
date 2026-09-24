#!/usr/bin/env bash
# Publish SurviveTheWolverine.rbxlx straight to Roblox with the Open Cloud
# Place Publishing API (no Studio needed).
#
# Needs these environment variables:
#   ROBLOX_API_KEY      Open Cloud API key with "universe-places: write" for this experience
#   ROBLOX_UNIVERSE_ID  the experience (universe) ID
#   ROBLOX_PLACE_ID     the start place ID
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_UNIVERSE_ID:?set ROBLOX_UNIVERSE_ID}"
: "${ROBLOX_PLACE_ID:?set ROBLOX_PLACE_ID}"
FILE=${1:-SurviveTheWolverine.rbxlx}
echo "Publishing $FILE to universe $ROBLOX_UNIVERSE_ID place $ROBLOX_PLACE_ID ..."
curl -sS --fail-with-body -X POST \
  "https://apis.roblox.com/universes/v1/${ROBLOX_UNIVERSE_ID}/places/${ROBLOX_PLACE_ID}/versions?versionType=Published" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/xml" \
  --data-binary @"$FILE"
echo
echo "Published."
