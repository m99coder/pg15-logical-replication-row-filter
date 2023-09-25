# pg15-logical-replication-row-filter

> PoC for using the Postgres 15 built-in row filter for logical replication

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
  basht             Run interactive shell in target
  psqls             Connect to source
  psqlt             Connect to target
  pgdata            Run pgbench to create data
  pgdatadrop        Drop tables created by pgbench
  pgpub             Create publication
  pgpubdrop         Drop publication
  pgsub             Create subscription
  pgsubdrop         Drop subscription
```

## Flow

```shell
# start both database instances
→ make start

# create schema in both instances, populate data into source
→ make pgdata

# create publication in source
→ make pgpub

# create subscription in target
→ make pgsub
```

## Resources

- <https://1kevinson.com/how-to-create-a-postgres-database-in-docker/>
- <https://peterevans.dev/posts/how-to-wait-for-container-x-before-starting-y/>
- <https://www.cloudbees.com/blog/tuning-postgresql-with-pgbench>
- <https://www.postgresql.org/docs/current/pgbench.html>
- <https://www.postgresql.org/docs/current/logical-replication-row-filter.html>
- <https://matthewmoisen.com/blog/posgresql-logical-replication/>
