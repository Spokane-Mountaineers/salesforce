# Show available recipes
default:
    @just --list

# Run Docs Server
serve:
    @echo ➤ starting dev server
    @docker run --rm -it -p 8000:8000 -v $PWD:/docs squidfunk/mkdocs-material:9.7.6

# Build the docs and fail on broken links or nav (parity with CI --strict)
build-docs:
    @echo ➤ building docs (strict)
    @docker run --rm -v $PWD:/docs squidfunk/mkdocs-material:9.7.6 build --strict

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
    @docker run --platform=linux/amd64 --rm -v $PWD:/code -w /code markdownlint/markdownlint **/*.md

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
