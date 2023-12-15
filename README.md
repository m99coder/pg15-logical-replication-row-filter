# pg15-logical-replication-row-filter

> PoC for using the Postgres 15 built-in row filter for logical replication

The scenario this PoC tries to simulate and demonstrate is as follows: We set up a logical replication with a row filter, populate two database instances with different data and check if the replication is valid by comparing some numbers between the source and the target of the operation.

As primary key and row filter for the logical replication, we use the criteria `bid = 1`. Logical replication requires the row filter criteria to be part of the primary key for the related table. Another requirement is non-overlapping data on both database instances. So we had to tweak `pgbench` a bit, which is used for the data population part and traffic simulation part. Even identifiers are entered in the source, odd identifiers in the target.

## Prerequisites

Make sure that the `.envrc` file is sourced before you start. You can do so by using [direnv](https://direnv.net/).

## Important files

- [sql/pgbench_alter.sql](./sql/pgbench_alter.sql): Extend the primary keys in the tables `pgbench_accounts` and `pgbench_tellers` to contain `bid` as well.
- [sql/pgbench_init_pub.sql](./sql/pgbench_init_pub.sql), [sql/pgbench_init_sub.sql](./sql/pgbench_init_sub.sql): Init pgbench tables `pgbench_branches`, `pgbench_tellers`, and `pgbench_accounts` with entries where the primary keys follow the even/odd pattern for the source and the target. _The scale factor of 50 is applied as static value in these files and needs to be adjusted if the environment variable `PGBENCH_SCALE` is modified._
- [sql/repl_pub.sql](./sql/repl_pub.sql): Create publication for all pgbench tables using the row filter criteria `bid = 1` on the source.
- [sql/repl_sub.sql](./sql/repl_sub.sql): Create subscription for the publication in the target.
- [bench/pub.bench](./bench/pub.bench), [bench/sub.bench](./bench/sub.bench): Benchmark scripts to use with modified identifiers following the even/odd pattern for the source and the target.
- [sql/validate.sql](./sql/validate.sql): Queries to validate replication success by comparing balance values and sums, as well as the count of history entries for every row with a reference to `bid = 1`.

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

## Concept

<https://www.postgresql.org/docs/15/logical-replication.html>

> Logical replication of a table typically starts with taking a snapshot of the data on the publisher database and copying that to the subscriber. Once that is done, the changes on the publisher are sent to the subscriber as they occur in real-time. The subscriber applies the data in the same order as the publisher so that transactional consistency is guaranteed for publications within a single subscription.

Publications

> Publications can choose to limit the changes they produce to any combination of `INSERT`, `UPDATE`, `DELETE`, and `TRUNCATE`, similar to how triggers are fired by particular event types. By default, all operation types are replicated. These publication specifications apply only for DML operations; they do not affect the initial data synchronization copy. Row filters have no effort for `TRUNCATE`.
>
> A published table must have a “replica identity” configured in order to be able to replicate `UPDATE` and `DELETE` operations, so that appropriate rows to update or delete can be identified on the subscriber side. By default, this is the primary key, if there is one. Another unique index (with certain additional requirements) can also be set to be the replica identity.

```sql
-- using default replica identity (primary key)
ALTER TABLE pgbench_branches
  REPLICA IDENTITY DEFAULT;

-- using the given index
ALTER TABLE pgbench_branches
  REPLICA IDENTITY USING INDEX pgbench_branches_pkey;

-- don’t use `FULL` as it means a lot of data in the WAL
```

Subscriptions

> Each subscription will receive changes via one replication slot. Additional replication slots may be required for the initial data synchronization of pre-existing table data and those will be dropped at the end of data synchronization.
>
> The subscription is added using `CREATE SUBSCRIPTION` and can be stopped/resumed at any time using the `ALTER SUBSCRIPTION` command and removed using `DROP SUBSCRIPTION`.
>
> The schema definitions are not replicated, and the published tables must exist on the subscriber. Only regular tables may be the target of replication. For example, you can’t replicate to a view.
>
> Normally, the remote replication slot is created automatically when the subscription is created using `CREATE SUBSCRIPTION` and it is dropped automatically when the subscription is dropped using `DROP SUBSCRIPTION`.

Row Filters

> If a published table sets a row filter, a row is replicated only if its data satisfies the row filter expression. This allows a set of tables to be partially replicated. The row filter is defined per table. Use a `WHERE` clause after the table name for each published table that requires data to be filtered out. The `WHERE` clause must be enclosed by parentheses.
>
> Row filters are applied before publishing the changes. If the row filter evaluates to `false` or `NULL` then the row is not replicated. The `WHERE` clause expression is evaluated with the same role used for the replication connection. Row filters have no effect for `TRUNCATE` command.
>
> If a publication publishes `UPDATE` or `DELETE` operations, the row filter WHERE clause must contain only columns that are covered by the replica identity. If a publication publishes only `INSERT` operations, the row filter `WHERE` clause can use any column.
>
> Whenever an `UPDATE` is processed, the row filter expression is evaluated for both the old and new row (i.e. using the data before and after the update). If both evaluations are `true`, it replicates the `UPDATE` change. If both evaluations are `false`, it doesn’t replicate the change. If only one of the old/new rows matches the row filter expression, the `UPDATE` is transformed to `INSERT` or `DELETE`, to avoid any data inconsistency.
>
> If the subscription requires copying pre-existing table data and a publication contains `WHERE` clauses, only data that satisfies the row filter expressions is copied to the subscriber.

Column Lists

> Each publication can optionally specify which columns of each table are replicated to subscribers. The table on the subscriber side must have at least all the columns that are published. If no column list is specified, then all columns on the publisher are replicated.

Conflicts

> Logical replication behaves similarly to normal DML operations in that the data will be updated even if it was changed locally on the subscriber node. If incoming data violates any constraints the replication will stop. This is referred to as a _conflict_. When replicating `UPDATE` or `DELETE` operations, missing data will not produce a conflict and such operations will simply be skipped.
>
> A conflict will produce an error and will stop the replication; it must be resolved manually by the user. Details about the conflict can be found in the subscriber’s server log. The resolution can be done either by changing data or permissions on the subscriber so that it does not conflict with the incoming change or by skipping the transaction that conflicts with the existing data.
>
> The transaction that produced the conflict can be skipped by using `ALTER SUBSCRIPTION ... SKIP` with the finish LSN. The finish LSN could be an LSN at which the transaction is committed or prepared on the publisher. Alternatively, the transaction can also be skipped by calling the `pg_replication_origin_advance()` function. Before using this function, the subscription needs to be disabled temporarily either by `ALTER SUBSCRIPTION ... DISABLE` or, the subscription can be used with the `disable_on_error` option. Then, you can use `pg_replication_origin_advance()` function with the `node_name` and the next LSN of the finish LSN. The current position of origins can be seen in the `pg_replication_origin_status` system view. Please note that skipping the whole transaction includes skipping changes that might not violate any constraint. This can easily make the subscriber inconsistent.

Restrictions:

- The database schema and DDL commands are not replicated.
- Sequence data is not replicated.
- Replication of `TRUNCATE` commands is supported, but some care must be taken when truncating groups of tables connected by foreign keys.
- Large objects are not replicated.
- Replication is only supported by tables, including partitioned tables.
- When replicating between partitioned tables, the actual replication originates, by default, from the leaf partitions on the publisher, so partitions on the publisher must also exist on the subscriber as valid target tables.

Architecture

> Logical replication starts by copying a snapshot of the data on the publisher database. Once that is done, changes on the publisher are sent to the subscriber as they occur in real time. The subscriber applies data in the order in which commits were made on the publisher so that transactional consistency is guaranteed for the publications within any single subscription.
>
> Logical replication is built with an architecture similar to physical streaming replication. It is implemented by “walsender” and “apply” processes. The walsender process starts logical decoding of the WAL and loads the standard logical decoding plugin (`pgoutput`). The plugin transforms the changes read from WAL to the logical replication protocol and filters the data according to the publication specification. The data is then continuously transferred using the streaming replication protocol to the apply worker, which maps the data to local tables and applies the individual changes as they are received, in correct transactional order.
>
> The apply process on the subscriber database always runs with `session_replication_role` set to `replica`. This means that, by default, triggers and rules will not fire on a subscriber.

Initial Snapshot

> The initial data in existing subscribed tables are snapshotted and copied in a parallel instance of a special kind of apply process. This process will create its own replication slot and copy the existing data. As soon as the copy is finished the table contents will become visible to other backends. Once existing data is copied, the worker enters synchronization mode, which ensures that the table is brought up to a synchronized state with the main apply process by streaming any changes that happened during the initial data copy using standard logical replication. During this synchronization phase, the changes are applied and committed in the same order as they happened on the publisher. Once synchronization is done, control of the replication of the table is given back to the main apply process where replication continues as normal.

Monitoring

> The monitoring information about subscription is visible in `pg_stat_subscription`. This view contains one row for every subscription worker. A subscription can have zero or more active subscription workers depending on its state.
>
> Normally, there is a single apply process running for an enabled subscription. A disabled subscription or a crashed subscription will have zero rows in this view. If the initial data synchronization of any table is in progress, there will be additional workers for the tables being synchronized.

Configuration Settings

> On the publisher side, `wal_level` must be set to `logical`, and `max_replication_slots` must be set to at least the number of subscriptions expected to connect, plus some reserve for table synchronization. And `max_wal_senders` should be set to at least the same as `max_replication_slots` plus the number of physical replicas that are connected at the same time.
>
> `max_replication_slots` must also be set on the subscriber. It should be set to at least the number of subscriptions that will be added to the subscriber, plus some reserve for table synchronization. `max_logical_replication_workers` must be set to at least the number of subscriptions, again plus some reserve for the table synchronization. Additionally the `max_worker_processes` may need to be adjusted to accommodate for replication workers, at least `max_logical_replication_workers + 1`. Note that some extensions and parallel queries also take worker slots from `max_worker_processes`.

## Pause and Resume

First prepare tables and generate traffic.

```shell
make prepare -j 2
make run -j 2
```

And while the script is running, disable the subscription on the target.

```sql
ALTER SUBSCRIPTION sub_bid_1 DISABLE;
```

Validate the current state.

```shell
# we see inconsistent data
make validate
```

Re-enable the subscription on the target.

```sql
ALTER SUBSCRIPTION sub_bid_1 ENABLE;
```

Validate the final state.

```shell
# we see consistent data
make validate
```

The logs for the source look similar to these.

```text
STATEMENT:  START_REPLICATION SLOT "pg_16436_sync_16420_7283766544888864797" LOGICAL 0/A54C8A68 (proto_version '3', publication_names '"pub_bid_1"')
      LOG:  0/AC301478 has been already streamed, forwarding to 0/AC30A0F0
STATEMENT:  START_REPLICATION SLOT "sub_bid_1" LOGICAL 0/AC301478 (proto_version '3', publication_names '"pub_bid_1"')
      LOG:  starting logical decoding for slot "sub_bid_1"
   DETAIL:  Streaming transactions committing after 0/AC30A0F0, reading WAL from 0/A59D63F0.
STATEMENT:  START_REPLICATION SLOT "sub_bid_1" LOGICAL 0/AC301478 (proto_version '3', publication_names '"pub_bid_1"')
      LOG:  logical decoding found consistent point at 0/A59D63F0
   DETAIL:  There are no running transactions.
```

The logs for the target look similar to these.

```text
      LOG:  logical replication apply worker for subscription "sub_bid_1" will stop because the subscription was disabled
      LOG:  logical replication apply worker for subscription "sub_bid_1" has started
```

From the logs we see that the subscription was paused and resumed on the target, where the source did create the replication slot automatically as soon as the subscription was re-enabled and started to stream transactions.

The final `make validate` shows that the data is still consistent afterwards.

## Error Scenarios

### Violation of constraints

- Create pgbench schema
- Insert conflicting entry in target
- Create pgbench base data
- Setup publication and subscription

```shell
make conflict
```

The logs for the target look similar to these.

```text
      LOG:  logical replication table synchronization worker for subscription "sub_bid_1", table "pgbench_branches" has started
    ERROR:  duplicate key value violates unique constraint "pgbench_branches_pkey"
   DETAIL:  Key (bid)=(1) already exists.
  CONTEXT:  COPY pgbench_branches, line 1
      LOG:  background worker "logical replication worker" (PID 10848) exited with exit code 1
```

As long as the subscription is enabled, the logical replication is retried.

```shell
make reset -j 3
```

### Target goes down during replication

Start replication as usual.

```shell
make prepare -j 2
make run -j 2
```

While the replication runs, pause the target container and unpause it later.

```shell
docker compose pause pg15-repl-target
docker compose unpause pg15-repl-target
```

The logical replication resumes where it stopped and we get consistent data eventually.

```shell
make validate
```

## Resources

- <https://1kevinson.com/how-to-create-a-postgres-database-in-docker/>
- <https://peterevans.dev/posts/how-to-wait-for-container-x-before-starting-y/>
- <https://www.cloudbees.com/blog/tuning-postgresql-with-pgbench>
- <https://www.postgresql.org/docs/15/pgbench.html>
- <https://github.com/postgres/postgres/blob/master/src/bin/pgbench/pgbench.c#L5041>
- <https://www.postgresql.org/docs/15/logical-replication.html>
- <https://www.postgresql.org/docs/15/sql-altertable.html#SQL-ALTERTABLE-REPLICA-IDENTITY>
- <https://www.postgresql.org/docs/15/sql-altersubscription.html>
- <https://www.postgresql.org/docs/15/monitoring-stats.html>
- <https://matthewmoisen.com/blog/posgresql-logical-replication/>
- <https://andrewbridges.org/implementing-postgres-logical-replication/>
