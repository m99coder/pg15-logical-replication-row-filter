BEGIN;

-- https://github.com/postgres/postgres/blob/master/src/bin/pgbench/pgbench.c#L243-L246
-- #define nbranches 1
-- #define ntellers  10
-- #define naccounts 100000

--  1 being nbranches
-- 50 being :scale
INSERT INTO pgbench_branches(bid, bbalance)
  SELECT bid * 2 - 1, 0
  FROM generate_series(1, 1 * 50) AS bid;

-- 10 being ntellers
-- 50 being :scale
INSERT INTO pgbench_tellers(tid, bid, tbalance)
  SELECT tid * 2 - 1, ((tid - 1) / 10 + 1) * 2 - 1, 0
  FROM generate_series(1, 10 * 50) AS tid;

-- 100000 being naccounts
--     50 being :scale
INSERT INTO pgbench_accounts(aid, bid, abalance, filler)
  SELECT aid * 2 - 1, ((aid - 1) / 100000 + 1) * 2 - 1, 0, ''
  FROM generate_series(1, 100000 * 50) AS aid;

COMMIT;
