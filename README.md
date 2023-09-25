# pg15-logical-replication-row-filter

> PoC for using the Postgres 15 built-in row filter for logical replication

```shell
# force recreation of containers and detach them
docker compose up \
  --detach \
  --force-recreate

# show running services
docker compose ps

# show and follow logs
docker compose logs --follow

# stop services and clean up
docker compose down \
  --remove-orphans \
  --rmi all \
  --volumes
```

## Resources

- <https://1kevinson.com/how-to-create-a-postgres-database-in-docker/>
- <https://collabnix.com/getting-started-with-docker-and-postgresql/>
- <https://www.docker.com/blog/how-to-use-the-postgres-docker-official-image/>
