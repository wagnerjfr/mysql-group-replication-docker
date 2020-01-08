#!/bin/bash

for N in 1 2 3
do docker run -d --name=node$N --net=group1 --hostname=node$N \
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
  --group-replication-start-on-boot='OFF' \
  --group-replication-group-name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' \
  --group-replication-local-address="node$N:6606" \
  --group-replication-group-seeds='node1:6606,node2:6606,node3:6606' \
  --loose-group-replication-single-primary-mode='ON' \
  --loose-group-replication-enforce-update-everywhere-checks='OFF'
done
