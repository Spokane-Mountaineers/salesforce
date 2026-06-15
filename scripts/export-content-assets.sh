#!/usr/bin/env bash
# Export legacy Aura Content Asset image binaries into the content_assets static
# resource for the LWR content port.
#
# WHY prod: sandboxes copy ContentAsset/ContentVersion *records* but not the file
# *bytes* (VersionData is null in staging), so binaries must come from production.
# WHY this resource: /file-asset URLs only resolve inside Lightning Experience,
# not on the LWR member site — so images ship as a static resource instead.
#
# Usage: scripts/export-content-assets.sh <DeveloperName> [<DeveloperName> ...]
# Files land in force-app/main/default/staticresources/content_assets/<name>.<ext>
# Requires: an authenticated `production` org (sf org display --target-org production).
set -euo pipefail

DEST="force-app/main/default/staticresources/content_assets"
mkdir -p "$DEST"

read -r PTOKEN PINSTANCE < <(sf org display --target-org production --json \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['result']; print(d['accessToken'], d['instanceUrl'])")

for NAME in "$@"; do
  read -r CVID EXT < <(sf data query --target-org production --json --query \
    "SELECT Id, FileExtension FROM ContentVersion WHERE ContentDocumentId IN (SELECT ContentDocumentId FROM ContentAsset WHERE DeveloperName='${NAME}') AND IsLatest=true" \
    | python3 -c "import json,sys; r=json.load(sys.stdin)['result']['records']; print(r[0]['Id'], r[0]['FileExtension']) if r else print('', '')")
  if [ -z "$CVID" ]; then echo "  MISS  $NAME (no ContentAsset in prod)"; continue; fi
  OUT="$DEST/${NAME}.${EXT}"
  CODE=$(curl -s -o "$OUT" -w "%{http_code}" -H "Authorization: Bearer $PTOKEN" \
    "$PINSTANCE/services/data/v62.0/sobjects/ContentVersion/${CVID}/VersionData")
  SIZE=$(wc -c <"$OUT" | tr -d ' ')
  if [ "$CODE" = "200" ] && [ "$SIZE" -gt 0 ]; then
    echo "  OK    ${NAME}.${EXT} (${SIZE} bytes)"
  else
    echo "  FAIL  $NAME (http $CODE, $SIZE bytes)"; rm -f "$OUT"
  fi
done
