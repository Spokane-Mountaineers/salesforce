help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "} {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: serve
serve: ## Run Docs Server
	@echo ➤ starting dev server
	@docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material

.PHONY: lint
lint: ## Run linters
	@$(MAKE) lint-lwc
	@$(MAKE) lint-aura
	@$(MAKE) lint-docs

.PHONY: lint-lwc
lint-lwc: ## Lint Lightning Web Components with ESLint
	@echo ➤ linting LWC
	@npx eslint 'force-app/main/default/lwc/**/*.js'

.PHONY: lint-aura
lint-aura: ## Lint Aura components with ESLint
	@echo ➤ linting Aura
	@npx eslint 'force-app/main/default/aura/**/*.js'

.PHONY: lint-docs
lint-docs: ## Lint the documentation for issues
	@echo ➤ linting docs
	@docker run --platform=linux/amd64 --rm -v $(CURDIR):/code -w /code markdownlint/markdownlint **/*.md

# ============================================================================
# Salesforce environment switcher (direnv + .envrc.local)
# ============================================================================

.PHONY: env
env: ## Show the currently loaded Salesforce env
	@echo "SF_ENV=$${SF_ENV:-(unset — direnv may not be loaded)}"
	@echo "SF_TARGET_ORG=$${SF_TARGET_ORG:-(unset)}"
	@echo "SF_EXECUTION_USER=$${SF_EXECUTION_USER:-(unset)}"

.PHONY: use-staging
use-staging: ## Set local default env to staging (writes .envrc.local)
	@echo 'export SF_ENV=staging' > .envrc.local
	@echo "✓ wrote .envrc.local — direnv will reload on next prompt"

.PHONY: use-production
use-production: ## Set local default env to production (writes .envrc.local)
	@echo 'export SF_ENV=production' > .envrc.local
	@echo "✓ wrote .envrc.local — direnv will reload on next prompt"

# ============================================================================
# AuthProvider deploys
#
# Uses whatever SF_ENV direnv has loaded. To override for a single command:
#   make deploy-microsoft-auth SF_ENV=production
# (Make passes SF_ENV into the recipe shell; .envrc respects an inbound SF_ENV
# instead of consulting .envrc.local.)
# ============================================================================

.PHONY: deploy-authproviders
deploy-authproviders: ## Render and deploy all AuthProviders for current SF_ENV
	@direnv exec . ./scripts/deploy-authproviders.sh

.PHONY: deploy-google-auth
deploy-google-auth: ## Render and deploy only the Google AuthProvider
	@direnv exec . ./scripts/deploy-authproviders.sh Google

.PHONY: deploy-microsoft-auth
deploy-microsoft-auth: ## Render and deploy only the Microsoft AuthProvider
	@direnv exec . ./scripts/deploy-authproviders.sh Microsoft
