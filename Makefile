#!/usr/bin/make -f

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: start
start: ## Start services
	docker compose up --detach

.PHONY: stop
stop: ## Stop services
	docker compose down --remove-orphans

.PHONY: clean
clean: ## Clean up services
	docker compose down --remove-orphans --rmi all --volumes

.PHONY: logs
logs: ## Show service logs
	docker compose logs

.PHONY: ps
ps: ## Show running services
	docker compose ps

.PHONY: psqls
psqls: ## Connect to source
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p $${SOURCE_PORT} -U $${POSTGRES_USER} $${POSTGRES_DB}"

.PHONY: psqlt
psqlt: ## Connect to target
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p $${TARGET_PORT} -U $${POSTGRES_USER} $${POSTGRES_DB}"
