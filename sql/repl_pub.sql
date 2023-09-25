-- create publication on all four pgbench tables
-- with using a row filter
CREATE PUBLICATION pub_bid_1
  FOR TABLE
    pgbench_accounts WHERE (bid = 1),
    pgbench_branches WHERE (bid = 1),
    pgbench_history WHERE (bid = 1),
    pgbench_tellers WHERE (bid = 1);

-- short form if all tables should be replicated
-- CREATE PUBLICATION pub_bid_1
--   FOR ALL TABLES WHERE (bid = 1);

-- list publications with `\dRp+`
