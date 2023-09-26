# pg15-logical-replication-row-filter

> PoC for using the Postgres 15 built-in row filter for logical replication

The scenario this PoC tries to simulate and demonstrate is as follows: We set up a logical replication with a row filter, populate two database instances with different data and check if the replication is valid by comparing some numbers between the source and the target of the operation.

As primary key and row filter for the logical replication, we use the criteria `bid = 1`. Logical replication requires the row filter criteria to be part of the primary key for the related table. Another requirement is non-overlapping data on both database instances. So we had to tweak `pgbench` a bit, which is used for the data population part and traffic simulation part. Even identifiers are entered in the source, odd identifiers in the target.

## Makefile

Here is a trimmed down list of the most important make targets:

```text
Usage:
  make <target>
  help              Display this help
  start             Start services
  stop              Stop services
  clean             Clean up services
  logs              Show service logs
  ps                Show running services
  …
  prepare           Prepare schema, publication, and subscription
  run               Generate data in both instances
  validate          Validate replication
  reset             Reset everything
```

## Flow

These are the steps to run the scenario:

1. Start both instances in containers and apply the necessary configuration to them (`postgres.conf` is mounted)
2. Prepare both instances by creating the schema, populating the base data and setting up the publication as well as the subscription
3. Run the benchmark queries to simulate traffic and create entries for `bid = 1` which are replicated on the fly
4. Validate the results by comparing entry counts and balances for `bid = 1` on the source and the target
5. Reset data, publication, and subscription on both instances
6. Remove containers, volumes, and network

To achieve parallelism, the usage of `make` with the `-j` argument is important — optional for `prepare` and `reset`, but mandatory for `run`.

```shell
# start both database instances
make start

# create schema in both instances
# create publication
# create subscription
make prepare -j 2

# populate data in both instances
make run -j 2

# validate replication
make validate

# reset data in both instances
make reset -j 3

# stop both database instances
make stop
```

## Postgres

```sql
-- on source
SELECT * FROM pg_publication;
SELECT * FROM pg_replication_slots;

-- \dRp+
-- \d pgbench_branches

-- on target
SELECT * FROM pg_subscription;
```

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

demo=# \d pgbench_branches
              Table "public.pgbench_branches"
  Column  |     Type      | Collation | Nullable | Default
----------+---------------+-----------+----------+---------
 bid      | integer       |           | not null |
 bbalance | integer       |           |          |
 filler   | character(88) |           |          |
Indexes:
    "pgbench_branches_pkey" PRIMARY KEY, btree (bid)
Publications:
    "pub_bid_1" WHERE (bid = 1)

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
```

## Replication Stats

```sql
-- on source
SELECT * FROM pg_stat_replication WHERE application_name = 'sub_bid_1';
SELECT pg_current_wal_flush_lsn();
SELECT pg_current_wal_insert_lsn();
SELECT pg_current_wal_lsn();

-- on target
SELECT * FROM pg_stat_subscription WHERE subname = 'sub_bid_1';
SELECT * FROM pg_stat_subscription_stats WHERE subname = 'sub_bid_1';
```

### Source

```shell
demo=# SELECT * FROM pg_stat_replication WHERE application_name = 'sub_bid_1';
-[ RECORD 1 ]----+------------------------------
pid              | 146
usesysid         | 10
usename          | demo
application_name | sub_bid_1
client_addr      | 192.168.176.2
client_hostname  |
client_port      | 33092
backend_start    | 2023-09-26 08:26:03.334842+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/5DBC7178
write_lsn        | 0/5DBC7178
flush_lsn        | 0/5DBC7178
replay_lsn       | 0/5DBC7178
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async
reply_time       | 2023-09-26 08:58:42.279064+00

demo=# SELECT pg_current_wal_flush_lsn();
-[ RECORD 1 ]------------+-----------
pg_current_wal_flush_lsn | 0/5DBC7178

demo=# SELECT pg_current_wal_insert_lsn();
-[ RECORD 1 ]-------------+-----------
pg_current_wal_insert_lsn | 0/5DBC7178

demo=# SELECT pg_current_wal_lsn();
-[ RECORD 1 ]------+-----------
pg_current_wal_lsn | 0/5DBC7178

demo=# SELECT
    confirmed_flush_lsn,
    pg_current_wal_lsn(),
    (pg_current_wal_lsn() - confirmed_flush_lsn) AS lsn_distance
FROM
    pg_catalog.pg_replication_slots
WHERE
    slot_name = 'sub_bid_1';
 confirmed_flush_lsn | pg_current_wal_lsn | lsn_distance
---------------------+--------------------+--------------
 0/5DBC7178          | 0/5DBC7178         |            0
(1 row)
```

The replication lag can be determined by subtracting `pg_current_wal_lsn()` from the `confirmed_flush_lsn` value of the replication slot in use.

### Target

```shell
demo=# SELECT * FROM pg_stat_subscription WHERE subname = 'sub_bid_1';
-[ RECORD 1 ]---------+------------------------------
subid                 | 16404
subname               | sub_bid_1
pid                   | 143
relid                 |
received_lsn          | 0/5DBC7178
last_msg_send_time    | 2023-09-26 09:03:43.498128+00
last_msg_receipt_time | 2023-09-26 09:03:43.498844+00
latest_end_lsn        | 0/5DBC7178
latest_end_time       | 2023-09-26 09:03:43.498128+00

demo=# SELECT * FROM pg_stat_subscription_stats WHERE subname = 'sub_bid_1';
-[ RECORD 1 ]-----+----------
subid             | 16404
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
- <https://andrewbridges.org/implementing-postgres-logical-replication/>
