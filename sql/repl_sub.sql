-- create subscription
CREATE SUBSCRIPTION sub_bid_1
  CONNECTION 'host=pg15-repl-source dbname=demo user=demo password=demo application_name=sub_bid_1'
  PUBLICATION pub_bid_1;
