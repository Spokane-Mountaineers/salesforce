# Show available recipes (grouped)
default:
    @just --list

# ── Docs ─────────────────────────────────────────────────────────────────────

# Run Docs Server
[group('docs')]
serve:
    @echo ➤ starting dev server
    @docker run --rm -it -p 8000:8000 -v $PWD:/docs squidfunk/mkdocs-material:9.7.6

# Build the docs and fail on broken links or nav (parity with CI --strict)
[group('docs')]
build-docs:
    @echo "➤ building docs (strict)"
    @docker run --rm -v $PWD:/docs squidfunk/mkdocs-material:9.7.6 build --strict

# ── Lint ─────────────────────────────────────────────────────────────────────

# Run linters
[group('lint')]
lint: lint-lwc lint-aura lint-docs

# Lint Lightning Web Components with ESLint
[group('lint')]
lint-lwc:
    @echo ➤ linting LWC
    @npx eslint 'force-app/main/default/lwc/**/*.js'

# Lint Aura components with ESLint
[group('lint')]
lint-aura:
    @echo ➤ linting Aura
    @npx eslint 'force-app/main/default/aura/**/*.js'

# Lint the documentation for issues
[group('lint')]
lint-docs:
    @echo ➤ linting docs
    @docker run --platform=linux/amd64 --rm -v $PWD:/code -w /code markdownlint/markdownlint **/*.md

# ── Test ─────────────────────────────────────────────────────────────────────

# Run LWC/Jest unit tests
[group('test')]
test-lwc:
    @echo ➤ running Jest (LWC)
    @npm run test:unit

# Run Node script contract tests (bundle normalizer, …)
[group('test')]
test-scripts:
    @echo ➤ running node script tests
    @node --test "scripts/**/*.test.mjs"

# ── Salesforce env ───────────────────────────────────────────────────────────

# Show the currently loaded Salesforce env
[group('salesforce')]
env:
    @echo "SF_ENV=${SF_ENV:-(unset — direnv may not be loaded)}"
    @echo "SF_TARGET_ORG=${SF_TARGET_ORG:-(unset)}"
    @echo "SF_EXECUTION_USER=${SF_EXECUTION_USER:-(unset)}"

# Select the active Salesforce env, e.g. `just use staging` → loads .env.staging (fails if that file is missing)
[group('salesforce')]
use env:
    @test -f .env.{{env}} || { echo "✗ .env.{{env}} does not exist — available: $(ls .env.* 2>/dev/null | sed 's|\.env\.||' | tr '\n' ' ')"; exit 1; }
    @echo 'export SF_ENV={{env}}' > .envrc.local
    @echo "✓ SF_ENV={{env}} (wrote .envrc.local) — direnv will reload on next prompt"

# Mirror the canonical SMI theme into the Salesforce static resource
[group('salesforce')]
sync-theme:
    @echo "➤ syncing smi-theme.css → smi_theme static resource"
    @cp docs/stylesheets/smi-theme.css force-app/main/default/staticresources/smi_theme.css
    @echo "✓ synced (commit both copies)"

# ── Auth providers ───────────────────────────────────────────────────────────

# Render and deploy all AuthProviders for current SF_ENV
[group('auth')]
deploy-authproviders:
    @direnv exec . ./scripts/deploy-authproviders.sh

# Render and deploy only the Google AuthProvider
[group('auth')]
deploy-google-auth:
    @direnv exec . ./scripts/deploy-authproviders.sh Google

# Render and deploy only the Microsoft AuthProvider
[group('auth')]
deploy-microsoft-auth:
    @direnv exec . ./scripts/deploy-authproviders.sh Microsoft

# ── LWR Experience site ──────────────────────────────────────────────────────
# docs/plans/2026-06-08-lwr-site-overhaul.md. All site recipes act on the active
# SF_ENV (selected via `just use <env>`); there is no per-recipe <org> argument.
# Org-specific values come from .env.<SF_ENV> (SITE_NAME, SITE_BUNDLE, …).

# Create the LWR site in the active org from SITE_* env (bootstrap; fails if it exists)
[group('lwr site')]
create-site:
    @echo "➤ creating '$SITE_NAME' [$SITE_TEMPLATE] in org '$SF_TARGET_ORG' (SF_ENV=$SF_ENV)"
    sf community create \
      --name "$SITE_NAME" \
      --template-name "$SITE_TEMPLATE" \
      --url-path-prefix "$SITE_URL_PATH_PREFIX" \
      --target-org "$SF_TARGET_ORG" \
      templateParams.AuthenticationType="$SITE_AUTH_TYPE"

# Pull the site bundle from the active org, normalize, and leave for review/commit
[group('lwr site')]
refresh:
    @echo "➤ retrieving $SITE_BUNDLE from '$SF_TARGET_ORG' (SF_ENV=$SF_ENV)"
    sf project retrieve start --metadata "DigitalExperienceBundle:$SITE_BUNDLE" --target-org "$SF_TARGET_ORG"
    @echo "➤ normalizing bundle for a reviewable diff"
    @node scripts/normalize-experience-bundle.mjs
    @echo "✓ refreshed — review 'git diff', commit staff-owned page changes, then rebase code on top"

# Deploy source to the active org (sync theme first; guard + real tests on prod)
[group('lwr site')]
deploy:
    @just sync-theme
    @if [ "$SF_ENV" = "production" ]; then \
      printf '⚠  Deploying to PRODUCTION (org %s). Type "yes" to continue: ' "$SF_TARGET_ORG"; \
      read ans; [ "$ans" = "yes" ] || { echo "aborted."; exit 1; }; \
      echo "➤ prod deploy with RunLocalTests (prod rejects NoTestRun)"; \
      sf project deploy start --target-org "$SF_TARGET_ORG" --test-level RunLocalTests; \
    else \
      echo "➤ deploying to '$SF_TARGET_ORG' (SF_ENV=$SF_ENV)"; \
      sf project deploy start --target-org "$SF_TARGET_ORG"; \
    fi
    @echo "✓ deployed. If the site changed, run 'just publish' to make it live (publish is not part of deploy)."

# Deploy ONLY the Experience site bundle ($SITE_BUNDLE) to the active org (guard + real tests on prod)
[group('lwr site')]
deploy-site:
    @if [ "$SF_ENV" = "production" ]; then \
      printf '⚠  Deploying site bundle %s to PRODUCTION (org %s). Type "yes" to continue: ' "$SITE_BUNDLE" "$SF_TARGET_ORG"; \
      read ans; [ "$ans" = "yes" ] || { echo "aborted."; exit 1; }; \
      echo "➤ prod site deploy with RunLocalTests (prod rejects NoTestRun)"; \
      sf project deploy start --metadata "DigitalExperienceBundle:$SITE_BUNDLE" --target-org "$SF_TARGET_ORG" --test-level RunLocalTests; \
    else \
      echo "➤ deploying $SITE_BUNDLE to '$SF_TARGET_ORG' (SF_ENV=$SF_ENV)"; \
      sf project deploy start --metadata "DigitalExperienceBundle:$SITE_BUNDLE" --target-org "$SF_TARGET_ORG"; \
    fi
    @echo "✓ site bundle deployed. Run 'just publish' to make it live (publish is not part of deploy)."

# Render org-specific Network/CustomSite templates and deploy them
[group('lwr site')]
deploy-site-config:
    @direnv exec . ./scripts/deploy-site-config.sh

# Publish the Experience Builder site in the active org (make changes live)
[group('lwr site')]
publish:
    @echo "➤ publishing '$SITE_NAME' in '$SF_TARGET_ORG' (SF_ENV=$SF_ENV)"
    sf community publish --name "$SITE_NAME" --target-org "$SF_TARGET_ORG"

# Non-mutating drift check: compare the active org's bundle against committed source
[group('lwr site')]
diff-site:
    @git diff --quiet -- force-app/main/default/digitalExperiences || { echo "✗ bundle has uncommitted changes — commit or stash them before diff-site"; exit 1; }
    @echo "➤ retrieving live bundle to compare (working tree restored afterward)"
    @sf project retrieve start --metadata "DigitalExperienceBundle:$SITE_BUNDLE" --target-org "$SF_TARGET_ORG" >/dev/null
    @node scripts/normalize-experience-bundle.mjs >/dev/null
    @git --no-pager diff --stat -- force-app/main/default/digitalExperiences || true
    @git --no-pager diff -- force-app/main/default/digitalExperiences || true
    @git restore -- force-app/main/default/digitalExperiences
    @echo "✓ drift shown above; working tree restored to committed state"
