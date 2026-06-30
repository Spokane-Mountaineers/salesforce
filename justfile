# Show available recipes
default:
    @just --list

# Run Docs Server
serve:
    @echo ➤ starting dev server
    @docker run --rm -it -p 8000:8000 -v "$(pwd -P)":/docs zensical/zensical:0.0.45 serve --dev-addr 0.0.0.0:8000

# Build the docs and fail on broken links or nav (parity with CI --strict)
# Uses pwd -P so the macOS /tmp -> /private/tmp symlink is resolved before
# Docker sees the mount source (otherwise the container gets an empty /docs).
# Also mounts the git common dir so git-revision-date works inside worktrees,
# where .git is a file pointing at a gitdir outside the mounted tree.
build-docs:
    @echo "➤ building docs (strict)"
    @docker run --rm \
        -v "$(pwd -P)":/docs \
        -v "$(git rev-parse --path-format=absolute --git-common-dir)":"$(git rev-parse --path-format=absolute --git-common-dir)" \
        -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*' \
        zensical/zensical:0.0.45 build --strict

# Mirror the canonical SMI theme into the Salesforce static resource
sync-theme:
    @echo "➤ syncing smi-theme.css → smi_theme static resource"
    @cp docs/stylesheets/smi-theme.css force-app/main/default/staticresources/smi_theme.css
    @echo "✓ synced (commit both copies)"

# Run linters
lint: lint-lwc lint-aura lint-docs

# Lint Lightning Web Components with ESLint
lint-lwc:
    @echo ➤ linting LWC
    @npx eslint 'force-app/main/default/lwc/**/*.js'

# Lint Aura components with ESLint
lint-aura:
    @echo ➤ linting Aura
    @npx eslint 'force-app/main/default/aura/**/*.js'

# Lint the documentation for issues
lint-docs:
    @echo ➤ linting docs
    @docker run --platform=linux/amd64 --rm -v "$(pwd -P)":/code -w /code markdownlint/markdownlint **/*.md

# Show the currently loaded Salesforce env
env:
    @echo "SF_ENV=${SF_ENV:-(unset — direnv may not be loaded)}"
    @echo "SF_TARGET_ORG=${SF_TARGET_ORG:-(unset)}"
    @echo "SF_EXECUTION_USER=${SF_EXECUTION_USER:-(unset)}"

# Set local default env to staging (writes .envrc.local)
use-staging:
    @echo 'export SF_ENV=staging' > .envrc.local
    @echo "✓ wrote .envrc.local — direnv will reload on next prompt"

# Set local default env to production (writes .envrc.local)
use-production:
    @echo 'export SF_ENV=production' > .envrc.local
    @echo "✓ wrote .envrc.local — direnv will reload on next prompt"

# Render and deploy all AuthProviders for current SF_ENV
deploy-authproviders:
    @direnv exec . ./scripts/deploy-authproviders.sh

# Render and deploy only the Google AuthProvider
deploy-google-auth:
    @direnv exec . ./scripts/deploy-authproviders.sh Google

# Render and deploy only the Microsoft AuthProvider
deploy-microsoft-auth:
    @direnv exec . ./scripts/deploy-authproviders.sh Microsoft
