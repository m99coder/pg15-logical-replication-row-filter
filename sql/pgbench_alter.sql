BEGIN;

-- drop primary key constraints and update them
ALTER TABLE pgbench_accounts DROP CONSTRAINT pgbench_accounts_pkey;
ALTER TABLE pgbench_accounts ADD PRIMARY KEY (aid, bid);

ALTER TABLE pgbench_tellers DROP CONSTRAINT pgbench_tellers_pkey;
ALTER TABLE pgbench_tellers ADD PRIMARY KEY (tid, bid);

COMMIT;
