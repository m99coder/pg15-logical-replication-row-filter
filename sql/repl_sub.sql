-- create subscription
CREATE SUBSCRIPTION sub_bid_1
  CONNECTION 'postgresql://demo:demo@pg15-repl-source/demo?application_name=sub_bid_1'
  PUBLICATION pub_bid_1;
