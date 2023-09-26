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

.PHONY: bashs
bashs: ## Run interactive shell in source
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash

.PHONY: basht
basht: ## Run interactive shell in target
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash

.PHONY: psqls
psqls: ## Connect to source
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"

.PHONY: psqlt
psqlt: ## Connect to target
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"

.PHONY: pginit
pginit: ## Run initialization for pgbench
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) pgbench -i -I t -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB} < /opt/sql/pgbench_init_pub.sql"
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) pgbench -i -I t -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB} < /opt/sql/pgbench_init_sub.sql"

.PHONY: pgdata
pgdata: ## Run pgbench to create data
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) pgbench -c 10 -j 2 -t 10000 -s $${PGBENCH_SCALE} -f /opt/bench/pub.bench -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) pgbench -c 10 -j 2 -t 10000 -s $${PGBENCH_SCALE} -f /opt/bench/sub.bench -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"

.PHONY: pgdatadrop
pgdatadrop: ## Drop tables created by pgbench
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) pgbench -i -I d -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) pgbench -i -I d -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"

.PHONY: pgpub
pgpub: ## Create publication
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB} < /opt/sql/repl_pub.sql"

.PHONY: pgpubdrop
pgpubdrop: ## Drop publication
	docker exec -it $${CONTAINER_NAME_PREFIX}-source /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -c 'DROP PUBLICATION IF EXISTS pub_bid_1' -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"

.PHONY: pgsub
pgsub: ## Create subscription
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB} < /opt/sql/repl_sub.sql"

.PHONY: pgsubdrop
pgsubdrop: ## Drop subscription
	docker exec -it $${CONTAINER_NAME_PREFIX}-target /bin/bash -c "PGPASSWORD=$$(echo $$POSTGRES_PASSWORD) psql -c 'DROP SUBSCRIPTION IF EXISTS sub_bid_1' -h localhost -p 5432 -U $${POSTGRES_USER} $${POSTGRES_DB}"

.PHONY: prepare
prepare: pginit pgdata pgpub ## Prepare schema, data and publication

.PHONY: replicate
replicate: pgsub ## Create subscription and run replication

.PHONY: reset
reset: pgsubdrop pgpubdrop pgdatadrop ## Reset everything
