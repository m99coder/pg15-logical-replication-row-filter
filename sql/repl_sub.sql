-- create subscription
CREATE SUBSCRIPTION sub_bid_1
  CONNECTION 'postgresql://demo:demo@pg15-repl-source.pg15-logical-replication-row-filter_default/demo?application_name=sub_bid_1'
  PUBLICATION pub_bid_1;
