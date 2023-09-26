SELECT bbalance FROM pgbench_branches WHERE bid = 1;
SELECT SUM(abalance) FROM pgbench_accounts WHERE bid = 1;
SELECT SUM(tbalance) FROM pgbench_tellers WHERE bid = 1;
