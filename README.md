[![Build Status](https://travis-ci.com/wagnerjfr/mysql-group-replication-docker.svg?branch=master)](https://travis-ci.com/wagnerjfr/mysql-group-replication-docker)

# MySQL Group Replication with Docker MySQL Images
Setting up Group Replication with Docker MySQL images

#### The MySQL Group Replication feature is a multi-master update anywhere replication plugin  for MySQL with built-in conflict detection and resolution, automatic distributed recovery, and group membership.

## Full article
https://dev.mysql.com/blog-archive/setting-up-mysql-group-replication-with-mysql-docker-images/

## References
https://dev.mysql.com/doc/refman/8.0/en/group-replication.html

## Other ways to setup Group Replication using Docker containers
https://github.com/wagnerjfr/mysql-group-replication-docker

https://github.com/wagnerjfr/mysql-group-replication-binaries-docker

## YugabyteDB *(another database solution for creating a cluster)*
https://github.com/wagnerjfr/yugabytedb-docker-sample

## Prerequisites

1. Docker installed

## Overview

We start by pulling **mysql 8** from Docker Hub (https://hub.docker.com/r/mysql/mysql-server/), then we are going to create a Docker network named **group1** and finally setup a Group Replication topology with 4 group members in different hosts.

## Pulling MySQL Sever Image

To download the MySQL Community Edition image, the command is:
```
$ docker pull mysql/mysql-server:tag
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
Fire the following command to create a network:
```
$ docker network create group1
```
You just need to create it once, unless you remove it from Docker.

To see all Docker networks:
```
$ docker network ls
```
## Creating 3 MySQL 8 containers

Run the command below in a terminal for creating three MySQL 8 containers:

Note: If you wish to configure a **multi-primary mode** (which is the MySQL GR's default mode), change the `loose-group-replication-single-primary-mode` and `loose-group-replication-enforce-update-everywhere-checks` values to `OFF` and `ON` respectively. For a single-primary mode, just leave as it is.

![alt text](https://github.com/wagnerjfr/mysql-group-replication-docker/blob/master/figures/group_replication_single_multi_primary.png)

```
for N in 1 2 3
do docker run -d --name=node$N --net=group1 --hostname=node$N \
  -v $PWD/d$N:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass \
  mysql/mysql-server:8.0 \
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
  --loose-group-replication-local-address="node$N:6606" \
  --loose-group-replication-group-seeds='node1:6606,node2:6606,node3:6606' \
  --loose-group-replication-single-primary-mode='ON' \
  --loose-group-replication-enforce-update-everywhere-checks='OFF'
done
```
It's possible to see whether the containers are started by running:
```
$ docker ps -a
```
![alt text](https://github.com/wagnerjfr/mysql-group-replication-docker/blob/master/figures/Docker-GR-Image1.png)

The above image you can see that the containers are starting.
![alt text](https://github.com/wagnerjfr/mysql-group-replication-docker/blob/master/figures/Docker-GR-Image2.png)

After some seconds, all 3 containers are up and running.

If some problem happens and one or more containers are not started, we can check the MySQL logs running (for instance in node1):
```
$ docker logs node1
```
P.S. You must always remember to remove a stopped container (for instance running: `docker rm node1`) and delete the MySQL data directory which was created, before running a new container with an existing name again.

## Setup and start a group replication in the containers

### node1

Run these commands in terminal:
```
$ docker exec -t node1 mysql -uroot -pmypass \
  -e "SET @@GLOBAL.group_replication_bootstrap_group=1;" \
  -e "create user 'repl'@'%';" \
  -e "GRANT REPLICATION SLAVE ON *.* TO repl@'%';" \
  -e "flush privileges;" \
  -e "change master to master_user='root' for channel 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;" \
  -e "SET @@GLOBAL.group_replication_bootstrap_group=0;" \
  -e "SELECT * FROM performance_schema.replication_group_members;"
```

### node2 and node3

Run these commands in terminal:
```
for N in 2 3
do docker exec -t node$N mysql -uroot -pmypass \
  -e "change master to master_user='repl' for channel 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;"
done
```
And finally:
```
for N in 1 2 3
do docker exec -t node$N mysql -uroot -pmypass \
  -e "SHOW VARIABLES WHERE Variable_name = 'hostname';" \
  -e "SELECT * FROM performance_schema.replication_group_members;"
done
```

By now, you should see:
```console
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| hostname      | node1 |
+---------------+-------+
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| group_replication_applier | 2bcbd64e-1982-11e9-b234-0242ac150002 | node1       |        3306 | ONLINE       | PRIMARY     | 8.0.13         |
| group_replication_applier | 2c635537-1982-11e9-869f-0242ac150003 | node2       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
| group_replication_applier | 2cec4447-1982-11e9-9893-0242ac150004 | node3       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| hostname      | node2 |
+---------------+-------+
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| group_replication_applier | 2bcbd64e-1982-11e9-b234-0242ac150002 | node1       |        3306 | ONLINE       | PRIMARY     | 8.0.13         |
| group_replication_applier | 2c635537-1982-11e9-869f-0242ac150003 | node2       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
| group_replication_applier | 2cec4447-1982-11e9-9893-0242ac150004 | node3       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| hostname      | node3 |
+---------------+-------+
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| group_replication_applier | 2bcbd64e-1982-11e9-b234-0242ac150002 | node1       |        3306 | ONLINE       | PRIMARY     | 8.0.13         |
| group_replication_applier | 2c635537-1982-11e9-869f-0242ac150003 | node2       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
| group_replication_applier | 2cec4447-1982-11e9-9893-0242ac150004 | node3       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
```

## Add a new node to group

Let's start a container ***node4***:
```
docker run -d --name=node4 --net=group1 --hostname=node4 \
  -v $PWD/d4:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass \
  mysql/mysql-server:8.0 \
  --server-id=4 \
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
  --loose-group-replication-local-address="node4:6606" \
  --loose-group-replication-group-seeds='node1:6606,node2:6606,node3:6606' \
  --loose-group-replication-single-primary-mode='ON' \
  --loose-group-replication-enforce-update-everywhere-checks='OFF'
```
Wait for state ```Up (healthy)``` and run the command below:
```
docker exec -t node4 mysql -uroot -pmypass \
  -e "change master to master_user='repl' for channel 'group_replication_recovery';" \
  -e "START GROUP_REPLICATION;"
```
Finally execute:
```
docker exec -t node4 mysql -uroot -pmypass \
  -e "SHOW VARIABLES WHERE Variable_name = 'hostname';" \
  -e "SELECT * FROM performance_schema.replication_group_members;"
```
The below output should be printed:
```console
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| hostname      | node4 |
+---------------+-------+
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
| group_replication_applier | 2bcbd64e-1982-11e9-b234-0242ac150002 | node1       |        3306 | ONLINE       | PRIMARY     | 8.0.13         |
| group_replication_applier | 2c635537-1982-11e9-869f-0242ac150003 | node2       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
| group_replication_applier | 2cec4447-1982-11e9-9893-0242ac150004 | node3       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
| group_replication_applier | d2e4b780-1982-11e9-b082-0242ac150005 | node4       |        3306 | ONLINE       | SECONDARY   | 8.0.13         |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+
```

## Cleaning up: stopping containers, removing created network and image

#### To stop the running container(s):
```
$ docker stop node1 node2 node3 node4
```
#### To remove the stopped container(s):
```
$ docker rm node1 node2 node3 node4
```
#### To remove the data directories created (they are located in the folder where the containers were started from):
```
$ sudo rm -rf d0 d1 d2 d3 d4
```
#### To remove the created network:
```
$ docker network rm group1
```
#### To remove the MySQL 8 image:
```
$ docker rmi mysql/mysql-server:8.0
```
