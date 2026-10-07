SHELL := /bin/bash
TFSTATE_RESOURCE_GROUP ?= sg-tfstate-rg
TFSTATE_CONTAINER ?= tfstate
BACKEND = -backend-config="resource_group_name=$(TFSTATE_RESOURCE_GROUP)" -backend-config="storage_account_name=$(TFSTATE_STORAGE_ACCOUNT)" -backend-config="container_name=$(TFSTATE_CONTAINER)" -backend-config="use_azuread_auth=true"
COMMONVARS = -var=subscription_id=$(ARM_SUBSCRIPTION_ID) -var=tenant_id=$(ARM_TENANT_ID) -var=infra_client_id=$(ARM_CLIENT_ID)

.PHONY: lint test
test:
	cd app/api && pip install -e '.[dev]' && pytest
	cd app/web && npm install && npm run test
lint:
	cd app/api && pip install -e '.[dev]' && ruff check .
	cd app/web && npm install && npm run lint
	terraform fmt -recursive -check infra
	helm lint helm/quiz-app

tf-init-shared:
	terraform -chdir=infra/shared init $(BACKEND) -backend-config="key=shared.tfstate"
tf-plan-shared: tf-init-shared
	terraform -chdir=infra/shared plan -lock-timeout=5m $(COMMONVARS)
tf-apply-shared: tf-init-shared
	terraform -chdir=infra/shared apply -lock-timeout=5m $(COMMONVARS)
tf-destroy-shared: tf-init-shared
	terraform -chdir=infra/shared destroy -lock-timeout=5m $(COMMONVARS)

tf-init-dev:
	terraform -chdir=infra/environments/dev init $(BACKEND) -backend-config="key=dev.tfstate"
tf-plan-dev: tf-init-dev
	terraform -chdir=infra/environments/dev plan -lock-timeout=5m $(COMMONVARS) -var=tfstate_storage_account=$(TFSTATE_STORAGE_ACCOUNT)
tf-apply-dev: tf-init-dev
	terraform -chdir=infra/environments/dev apply -lock-timeout=5m $(COMMONVARS) -var=tfstate_storage_account=$(TFSTATE_STORAGE_ACCOUNT)
tf-destroy-dev: tf-init-dev
	terraform -chdir=infra/environments/dev destroy -lock-timeout=5m $(COMMONVARS) -var=tfstate_storage_account=$(TFSTATE_STORAGE_ACCOUNT)

tf-init-prod:
	terraform -chdir=infra/environments/prod init $(BACKEND) -backend-config="key=prod.tfstate"
tf-plan-prod: tf-init-prod
	terraform -chdir=infra/environments/prod plan -lock-timeout=5m $(COMMONVARS) -var=tfstate_storage_account=$(TFSTATE_STORAGE_ACCOUNT)
tf-apply-prod: tf-init-prod
	terraform -chdir=infra/environments/prod apply -lock-timeout=5m $(COMMONVARS) -var=tfstate_storage_account=$(TFSTATE_STORAGE_ACCOUNT)
tf-destroy-prod: tf-init-prod
	terraform -chdir=infra/environments/prod destroy -lock-timeout=5m $(COMMONVARS) -var=tfstate_storage_account=$(TFSTATE_STORAGE_ACCOUNT)
