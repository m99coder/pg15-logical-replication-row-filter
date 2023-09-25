# pg15-logical-replication-row-filter

> PoC for using the Postgres 15 built-in row filter for logical replication

## Docker Compose

```shell
# force recreation of containers and detach them
→  docker compose up \
    --detach \
    --force-recreate

# show running services
→ docker compose ps

# show and follow logs
→ docker compose logs --follow

# stop services and clean up
→ docker compose down \
    --remove-orphans \
    --rmi all \
    --volumes
```

## Postgres

```shell
# connect to source database
→ PGPASSWORD=$(echo $POSTGRES_PASSWORD) psql \
    -h localhost -p ${SOURCE_PORT} -U ${POSTGRES_USER} ${POSTGRES_DB}

# connect to target database
→ PGPASSWORD=$(echo $POSTGRES_PASSWORD) psql \
    -h localhost -p ${TARGET_PORT} -U ${POSTGRES_USER} ${POSTGRES_DB}
```

## Makefile

```shell
→ make help

Usage:
  make <target>
  help              Display this help
  start             Start services
  stop              Stop services
  clean             Clean up services
  logs              Show service logs
  ps                Show running services
  psqls             Connect to source
  psqlt             Connect to target
  pgbinit           Initialize databases for pgbench
  pgbs              Run pgbench on source
  pgbt              Run pgbench on target
```

## Resources

- <https://1kevinson.com/how-to-create-a-postgres-database-in-docker/>
- <https://peterevans.dev/posts/how-to-wait-for-container-x-before-starting-y/>
- <https://www.cloudbees.com/blog/tuning-postgresql-with-pgbench>
