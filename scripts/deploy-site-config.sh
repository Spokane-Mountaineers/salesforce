#!/usr/bin/env bash
# Render the Experience site config (Network + CustomSite) from ${VAR}
# templates and deploy to Salesforce. These files live in force-app and are
# excluded from routine sf operations via .forceignore so the placeholders
# (staff emails, url prefix) never overwrite real org values on a refresh.
#
# This is bootstrap / config-reconciliation tooling — the bundle itself
# (digitalExperiences/**) deploys via `just deploy`, not here. You rarely need
# this on staging (the site is already configured); it exists so the site
# config is reproducible in another org (e.g. the prod cutover).
#
# Usage:
#   scripts/deploy-site-config.sh
#
# Required env vars (loaded by direnv from .env.<SF_ENV>; see .env.example):
#   SF_TARGET_ORG       - org alias (e.g. staging)
#   SITE_ADMIN_EMAIL    - CustomSite siteAdmin / guest record owner
#   SITE_SENDER_EMAIL   - Network email sender address

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/force-app/main/default"
RENDER_ROOT="$REPO_ROOT/tmp/site-config-render"
RENDER_DIR="$RENDER_ROOT/force-app/main/default"

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: required environment variable $name is not set." >&2
    echo "       Set it in .env.<SF_ENV> (loaded by direnv). See .env.example." >&2
    exit 1
  fi
}

require_var SF_TARGET_ORG
require_var SITE_ADMIN_EMAIL
require_var SITE_SENDER_EMAIL

rm -rf "$RENDER_ROOT"
mkdir -p "$RENDER_DIR/networks" "$RENDER_DIR/sites"
trap 'rm -rf "$RENDER_ROOT"' EXIT

# Restrict substitution to our own vars so nothing else in the XML is touched.
VARS='${SITE_ADMIN_EMAIL} ${SITE_SENDER_EMAIL}'

shopt -s nullglob
for f in "$SRC"/networks/*.network-meta.xml; do
  envsubst "$VARS" < "$f" > "$RENDER_DIR/networks/$(basename "$f")"
  echo "rendered $(basename "$f")"
done
for f in "$SRC"/sites/*.site-meta.xml; do
  envsubst "$VARS" < "$f" > "$RENDER_DIR/sites/$(basename "$f")"
  echo "rendered $(basename "$f")"
done

echo
echo "deploying Experience site config to org alias '$SF_TARGET_ORG'..."
sf project deploy start \
  --source-dir "$RENDER_DIR/networks" \
  --source-dir "$RENDER_DIR/sites" \
  --target-org "$SF_TARGET_ORG" \
  --ignore-conflicts
