#!/usr/bin/env bash
# Render AuthProvider XML templates with values from the environment, then
# deploy to Salesforce. Templates live in force-app/main/default/authproviders
# and are excluded from routine sf operations via .forceignore so the secret
# placeholders never overwrite real org values.
#
# Usage:
#   scripts/deploy-authproviders.sh                # deploys all providers
#   scripts/deploy-authproviders.sh Microsoft      # deploys one
#   scripts/deploy-authproviders.sh Google Microsoft
#
# Required env vars (loaded by direnv from .env; see .env.example):
#   SF_TARGET_ORG          - org alias (e.g. staging)
#   SF_EXECUTION_USER      - username AuthProviders run as
#   GOOGLE_CLIENT_ID       - if deploying Google
#   GOOGLE_CLIENT_SECRET   - if deploying Google
#   MICROSOFT_ENTRA_CLIENT_ID    - if deploying Microsoft
#   MICROSOFT_ENTRA_CLIENT_SECRET - if deploying Microsoft

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/force-app/main/default/authproviders"
RENDER_DIR="$REPO_ROOT/tmp/authproviders-render/authproviders"

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: required environment variable $name is not set." >&2
    echo "       Set it in .env (loaded by direnv). See .env.example." >&2
    exit 1
  fi
}

require_var SF_TARGET_ORG
require_var SF_EXECUTION_USER

if [ "$#" -eq 0 ]; then
  PROVIDERS=(Google Microsoft)
else
  PROVIDERS=("$@")
fi

for p in "${PROVIDERS[@]}"; do
  case "$p" in
    Google)
      require_var GOOGLE_CLIENT_ID
      require_var GOOGLE_CLIENT_SECRET
      ;;
    Microsoft)
      require_var MICROSOFT_ENTRA_CLIENT_ID
      require_var MICROSOFT_ENTRA_CLIENT_SECRET
      ;;
    *)
      echo "ERROR: unknown provider '$p' (expected: Google, Microsoft)" >&2
      exit 1
      ;;
  esac
  if [ ! -f "$SRC_DIR/$p.authprovider-meta.xml" ]; then
    echo "ERROR: template not found: $SRC_DIR/$p.authprovider-meta.xml" >&2
    exit 1
  fi
done

rm -rf "$RENDER_DIR"
mkdir -p "$RENDER_DIR"
trap 'rm -rf "$REPO_ROOT/tmp/authproviders-render"' EXIT

for p in "${PROVIDERS[@]}"; do
  src="$SRC_DIR/$p.authprovider-meta.xml"
  dst="$RENDER_DIR/$p.authprovider-meta.xml"
  envsubst < "$src" > "$dst"
  echo "rendered $p -> $dst"
done

echo
echo "deploying ${PROVIDERS[*]} to org alias '$SF_TARGET_ORG'..."
sf project deploy start \
  --source-dir "$RENDER_DIR" \
  --target-org "$SF_TARGET_ORG" \
  --ignore-conflicts
