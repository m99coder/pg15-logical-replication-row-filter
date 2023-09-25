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
  bashs             Run interactive shell in source
  basht             Run interactive shell in source
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
- <https://www.postgresql.org/docs/current/pgbench.html>
- <https://www.postgresql.org/docs/current/logical-replication-row-filter.html>
- <https://matthewmoisen.com/blog/posgresql-logical-replication/>
