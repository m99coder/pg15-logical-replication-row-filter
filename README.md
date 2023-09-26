# pg15-logical-replication-row-filter

> PoC for using the Postgres 15 built-in row filter for logical replication

## Makefile

```text
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
  pginit            Run initialization for pgbench
  pgdata            Run pgbench to create data
  pgdatadrop        Drop tables created by pgbench
  pgpub             Create publication
  pgpubdrop         Drop publication
  pgsub             Create subscription
  pgsubdrop         Drop subscription
  prepare           Prepare schema, data and publication
  replicate         Create subscription and run replication
  reset             Reset everything
```

## Flow

```shell
# start both database instances
make start

# create schema in both instances
# populate data into source
# create publication
make prepare

# create subscription and run replication
make replicate

# reset data in both instances
make reset

# stop both database instances
make stop
```

## Postgres

### Publication

```shell
demo=# SELECT * FROM pg_publication;
-[ RECORD 1 ]+----------
oid          | 16468
pubname      | pub_bid_1
pubowner     | 10
puballtables | f
pubinsert    | t
pubupdate    | t
pubdelete    | t
pubtruncate  | t
pubviaroot   | f

demo=# \dRp+
                          Publication pub_bid_1
 Owner | All tables | Inserts | Updates | Deletes | Truncates | Via root
-------+------------+---------+---------+---------+-----------+----------
 demo  | f          | t       | t       | t       | t         | f
Tables:
    "public.pgbench_accounts" WHERE (bid = 1)
    "public.pgbench_branches" WHERE (bid = 1)
    "public.pgbench_history" WHERE (bid = 1)
    "public.pgbench_tellers" WHERE (bid = 1)

demo=# SELECT * FROM pg_replication_slots;
-[ RECORD 1 ]-------+-----------
slot_name           | sub_bid_1
plugin              | pgoutput
slot_type           | logical
datoid              | 16384
database            | demo
temporary           | f
active              | t
active_pid          | 658
xmin                |
catalog_xmin        | 300789
restart_lsn         | 1/288715E0
confirmed_flush_lsn | 1/28871618
wal_status          | reserved
safe_wal_size       |
two_phase           | f

demo=# SELECT * FROM pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
pid              | 658
usesysid         | 10
usename          | demo
application_name | sub_bid_1
client_addr      | 192.168.112.3
client_hostname  |
client_port      | 56556
backend_start    | 2023-09-25 18:41:10.351454+00
backend_xmin     |
state            | streaming
sent_lsn         | 1/28871618
write_lsn        | 1/28871618
flush_lsn        | 1/28871618
replay_lsn       | 1/28871618
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async
reply_time       | 2023-09-25 18:44:53.765747+00
```

### Subscription

```shell
demo=# SELECT * FROM pg_subscription;
-[ RECORD 1 ]----+-------------------------------------------------------------------------------------
oid              | 16445
subdbid          | 16384
subskiplsn       | 0/0
subname          | sub_bid_1
subowner         | 10
subenabled       | t
subbinary        | f
substream        | f
subtwophasestate | d
subdisableonerr  | f
subconninfo      | host=pg15-repl-source dbname=demo user=demo password=demo application_name=sub_bid_1
subslotname      | sub_bid_1
subsynccommit    | off
subpublications  | {pub_bid_1}

demo=# SELECT * FROM pg_stat_subscription;
-[ RECORD 1 ]---------+------------------------------
subid                 | 16445
subname               | sub_bid_1
pid                   | 623
relid                 |
received_lsn          | 1/28871700
last_msg_send_time    | 2023-09-25 18:50:35.481432+00
last_msg_receipt_time | 2023-09-25 18:50:35.481557+00
latest_end_lsn        | 1/28871700
latest_end_time       | 2023-09-25 18:50:35.481432+00

demo=# SELECT * FROM pg_stat_subscription_stats;
-[ RECORD 1 ]-----+----------
subid             | 16445
subname           | sub_bid_1
apply_error_count | 0
sync_error_count  | 0
stats_reset       |
```

## Resources

- <https://1kevinson.com/how-to-create-a-postgres-database-in-docker/>
- <https://peterevans.dev/posts/how-to-wait-for-container-x-before-starting-y/>
- <https://www.cloudbees.com/blog/tuning-postgresql-with-pgbench>
- <https://www.postgresql.org/docs/15/pgbench.html>
- <https://github.com/postgres/postgres/blob/master/src/bin/pgbench/pgbench.c#L5041>
- <https://www.postgresql.org/docs/15/logical-replication.html>
- <https://www.postgresql.org/docs/15/monitoring-stats.html>
- <https://matthewmoisen.com/blog/posgresql-logical-replication/>
