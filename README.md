# MySQL Group Replication with Docker MySQL Images

#### The MySQL Group Replication feature is a multi-master update anywhere replication plugin  for MySQL with built-in conflict detection and resolution, automatic distributed recovery, and group membership.

## Full article
### [Setting up Group Replication with Docker MySQL images](https://medium.com/@wagnerjfr/setting-up-mysql-group-replication-with-mysql-docker-images-f5eedd44fa2b)

## Quick Start

Prerequisites: Docker installed, `MYSQL_VERSION` environment variable set (e.g., `8.0`).

```bash
MYSQL_VERSION=8.0

# 1. Pull MySQL image
docker pull mysql/mysql-server:${MYSQL_VERSION}

# 2. Create Docker network
docker network create groupnet

# 3. Launch 3 MySQL containers (multi-primary mode by default)
for N in 1 2 3
do docker run -d --name=node$N --net=groupnet --hostname=node$N \
  -v $PWD/d$N:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass \
  mysql/mysql-server:${MYSQL_VERSION} \
  --server-id=$N \
  --log-bin='mysql-bin-1.log' \
  --enforce-gtid-consistency='ON' \
  --log-slave-updates='ON' \
  --gtid-mode='ON' \
  --transaction-write-set-extraction='XXHASH64' \
  --binlog-checksum='NONE' \
  --master-info-repository='TABLE' \
  --relay-log-info-repository='TABLE' \
  --plugin-load='group_replication.so' \
  --relay-log-recovery='ON' \
  --loose-group-replication-start-on-boot='OFF' \
  --loose-group-replication-group-name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' \
  --loose-group-replication-local-address="node$N:33061" \
  --loose-group-replication-group-seeds='node1:33061,node2:33061,node3:33061' \
  --loose-group-replication-single-primary-mode='OFF' \
  --loose-group-replication-enforce-update-everywhere-checks='ON'
done

# Wait for containers to initialize (≈1 minute)
sleep 60

# 4. Bootstrap group on node1
docker exec -it node1 mysql -uroot -pmypass \
  -e "SET @@GLOBAL.group_replication_bootstrap_group=1;" \
  -e "CREATE USER 'repl'@'%';" \
  -e "GRANT REPLICATION SLAVE ON *.* TO repl@'%';" \
  -e "FLUSH PRIVILEGES;" \
  -e "CHANGE MASTER TO master_user='repl' FOR CHANNEL 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;" \
  -e "SET @@GLOBAL.group_replication_bootstrap_group=0;" \
  -e "SELECT * FROM performance_schema.replication_group_members;"

# 5. Join node2 and node3 to the group
for N in 2 3
do docker exec -it node$N mysql -uroot -pmypass \
  -e "CHANGE MASTER TO master_user='repl' FOR CHANNEL 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;"
done

# Verify all nodes are ONLINE
docker exec -it node1 mysql -uroot -pmypass \
  -e "SELECT * FROM performance_schema.replication_group_members;"
```

### Cleanup
```bash
docker stop node1 node2 node3
docker rm node1 node2 node3
rm -rf d1 d2 d3
docker network rm groupnet
```

For single-primary mode, change the two GR flags in the container launch command:
- `--loose-group-replication-single-primary-mode='ON'`
- `--loose-group-replication-enforce-update-everywhere-checks='OFF'`

For full details, testing, and fault tolerance scenarios, see the [full article](https://medium.com/@wagnerjfr/setting-up-mysql-group-replication-with-mysql-docker-images-f5eedd44fa2b).
