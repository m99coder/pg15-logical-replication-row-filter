FROM postgres:${PGVERSION}-alpine

LABEL author="Marco Lehmann"
LABEL description="Postgres Image for demoing logical replication using a row filter"
LABEL version="1.0"
