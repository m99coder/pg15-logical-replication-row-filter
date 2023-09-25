-- create publication on all four pgbench tables
-- with using a row filter
CREATE PUBLICATION pub_bid_1
  FOR TABLE pgbench_accounts, pgbench_branches, pgbench_history, pgbench_tellers
  WHERE (bid = 1);
