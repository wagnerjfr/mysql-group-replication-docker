# MySQL Group Replication with Docker MySQL Images
Setting up Group Replication with Docker MySQL images

#### The MySQL Group Replication feature is a multi-master update anywhere replication plugin  for MySQL with built-in conflict detection and resolution, automatic distributed recovery, and group membership.

## References
1. https://dev.mysql.com/doc/refman/8.0/en/group-replication.html
2. https://mysqlhighavailability.com/mysql-group-replication-its-in-5-7-17-ga/

## Another approach, using MySQL Binaries
https://github.com/wagnerjfr/mysql-group-replication-binaries-docker

## Prerequisites

1. Docker installed
2. Do not run while connected to VPN

## Overview

We start by creating a Docker network named **group1**, then we are going to pull **mysql 8** from Docker Hub (https://hub.docker.com/r/mysql/mysql-server/) and create a group replication topology with 3 group members in different hosts.

## Pull MySQL Sever Image

To download the MySQL Community Edition image, the command is:
```
docker pull mysql/mysql-server:tag
```
If :tag is omitted, the latest tag is used, and the image for the latest GA version of MySQL Server is downloaded.

Examples:
```
docker pull mysql/mysql-server
docker pull mysql/mysql-server:5.7
docker pull mysql/mysql-server:8.0
```
In this example, we are going to use ***mysql/mysql-server:8.0***

## Creating a Docker network
```
docker network create group1
```
Just need to create it once, unless you remove it from docker network.

To see all Docker Network:
```
docker network ls
```
## Creating 3 MySQL 8 containers

Run the commands below in a terminal.
```
docker run -d --rm --name=node1 --net=group1 --hostname=node1 \
  -v $PWD/d0:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass \
  mysql/mysql-server:8.0 \
  --server-id=1 \
  --log-bin='mysql-bin-1.log' \
  --enforce-gtid-consistency='ON' \
  --log-slave-updates='ON' \
  --gtid-mode='ON' \
  --transaction-write-set-extraction='XXHASH64' \
  --binlog-checksum='NONE' \
  --master-info-repository='TABLE' \
  --relay_log_info_repository='TABLE' \
  --plugin-load='group_replication.so' \
  --relay-log-recovery='ON' \
  --group_replication_start_on_boot='OFF' \
  --group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' \
  --group_replication_local_address='node1:6606' \
  --group_replication_group_seeds='node1:6606,node2:6606,node3:6606'

docker run -d --rm --name=node2 --net=group1 --hostname=node2 \
  -v $PWD/d1:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass \
  mysql/mysql-server:8.0 \
  --server-id=2 \
  --log-bin='mysql-bin-1.log' \
  --enforce-gtid-consistency='ON' \
  --log-slave-updates='ON' \
  --gtid-mode='ON' \
  --transaction-write-set-extraction='XXHASH64' \
  --binlog-checksum='NONE' \
  --master-info-repository='TABLE' \
  --relay_log_info_repository='TABLE' \
  --plugin-load='group_replication.so' \
  --relay-log-recovery='ON' \
  --group_replication_start_on_boot='OFF' \
  --group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' \
  --group_replication_local_address='node2:6606' \
  --group_replication_group_seeds='node1:6606,node2:6606,node3:6606'

docker run -d --rm --name=node3 --net=group1 --hostname=node3 \
  -v $PWD/d2:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass \
  mysql/mysql-server:8.0 \
  --server-id=3 \
  --log-bin='mysql-bin-1.log' \
  --enforce-gtid-consistency='ON' \
  --log-slave-updates='ON' \
  --gtid-mode='ON' \
  --transaction-write-set-extraction='XXHASH64' \
  --binlog-checksum='NONE' \
  --master-info-repository='TABLE' \
  --relay_log_info_repository='TABLE' \
  --plugin-load='group_replication.so' \
  --relay-log-recovery='ON' \
  --group_replication_start_on_boot='OFF' \
  --group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' \
  --group_replication_local_address='node3:6606' \
  --group_replication_group_seeds='node1:6606,node2:6606,node3:6606'
```
It's possible to see whether the containers are started by running:
```
docker ps -a
```
![alt text](https://github.com/wagnerjfr/mysql-group-replication-docker/blob/master/Docker-GR-Image1.png)

The above image you can see that the containers are starting.
![alt text](https://github.com/wagnerjfr/mysql-group-replication-docker/blob/master/Docker-GR-Image2.png)

After some seconds, all 3 containers are up and running.

## Setup and start a group replication in the containers

### node1

Run these commands in terminal:
```
docker exec -it node1 mysql -uroot -pmypass \
  -e "SET @@GLOBAL.group_replication_bootstrap_group=1;" \
  -e "create user 'root'@'%';" \
  -e "GRANT ALL  ON * . * TO root@'%';" \
  -e "flush privileges;" \
  -e "change master to master_user='root' for channel 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;" \
  -e "SELECT * FROM performance_schema.replication_group_members;"
```

### node2 and node3

Run these commands in terminal:
```
for N in 2 3
do docker exec -it node$N mysql -uroot -pmypass \
  -e "change master to master_user='root' for channel 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;"
done
```
And finally:
```
for N in 1 2 3
do docker exec -it node$N mysql -uroot -pmypass \
  -e "SHOW VARIABLES WHERE Variable_name = 'hostname';" \
  -e "SELECT * FROM performance_schema.replication_group_members;"
done
```

By now, you should see:
![alt text](https://github.com/wagnerjfr/mysql-group-replication-docker/blob/master/Docker-GR-Image3.png)

## Stopping containers, removing created network and image

In another terminal, run the below commands to:

#### Stopping running container(s):
```
docker stop node1 node2 node3
```
#### Removing the data directories created (they are located in the folder were the containers were run):
```
sudo rm -rf d0 d1 d2
```
#### Removing the created network:
```
docker network rm group1
```
#### Remove the MySQL 8 image:
```
docker rmi mysql/mysql-server:8.0
```
