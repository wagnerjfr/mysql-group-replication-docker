# MySQLGroupReplication with Docker MySQL Images
Setting up Group Replication with Docker MySQL images


## Prerequisites

1. Have Docker installed
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
docker run -d --rm --name=node1 --net=group1 --hostname=node1 -v $PWD/d0:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass mysql/mysql-server:8.0 --server-id=1 --log-bin='mysql-bin-1.log' --enforce-gtid-consistency='ON' --log-slave-updates='ON' --gtid-mode='ON' --transaction-write-set-extraction='XXHASH64' --binlog-checksum='NONE' --master-info-repository='TABLE' --relay_log_info_repository='TABLE' --plugin-load='group_replication.so' --relay-log-recovery='ON' --group_replication_start_on_boot='OFF' --group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' --group_replication_local_address='node1:6606' --group_replication_group_seeds='node1:6606,node2:6606,node3:6606' --group_replication_ip_whitelist='172.19.0.2,172.19.0.3,172.19.0.4' --group_replication_bootstrap_group='OFF' --group_replication_recovery_retry_count=5

docker run -d --rm --name=node2 --net=group1 --hostname=node2 -v $PWD/d1:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass mysql/mysql-server:8.0 --server-id=2 --log-bin='mysql-bin-1.log' --enforce-gtid-consistency='ON' --log-slave-updates='ON' --gtid-mode='ON' --transaction-write-set-extraction='XXHASH64' --binlog-checksum='NONE' --master-info-repository='TABLE' --relay_log_info_repository='TABLE' --plugin-load='group_replication.so' --relay-log-recovery='ON' --group_replication_start_on_boot='OFF' --group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' --group_replication_local_address='node2:6606' --group_replication_group_seeds='node1:6606,node2:6606,node3:6606' --group_replication_ip_whitelist='172.19.0.2,172.19.0.3,172.19.0.4' --group_replication_bootstrap_group='OFF' --group_replication_recovery_retry_count=5

docker run -d --rm --name=node3 --net=group1 --hostname=node3 -v $PWD/d2:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=mypass mysql/mysql-server:8.0 --server-id=3 --log-bin='mysql-bin-1.log' --enforce-gtid-consistency='ON' --log-slave-updates='ON' --gtid-mode='ON' --transaction-write-set-extraction='XXHASH64' --binlog-checksum='NONE' --master-info-repository='TABLE' --relay_log_info_repository='TABLE' --plugin-load='group_replication.so' --relay-log-recovery='ON' --group_replication_start_on_boot='OFF' --group_replication_group_name='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' --group_replication_local_address='node3:6606' --group_replication_group_seeds='node1:6606,node2:6606,node3:6606' --group_replication_ip_whitelist='172.19.0.2,172.19.0.3,172.19.0.4' --group_replication_bootstrap_group='OFF' --group_replication_recovery_retry_count=5
```
It's possible to see whether the containers are started by running:
```
docker ps -a
```
![alt text](https://github.com/wagnerjfr/MySQLGroupReplication/blob/master/Docker-GR-Image1.png)

The above image you can see that the container are starting.
![alt text](https://github.com/wagnerjfr/MySQLGroupReplication/blob/master/Docker-GR-Image2.png)

After some seconds, all 3 containers are up and running.

## Setup and start a group replication in the containers

Open 3 new terminals and run the below commands in each one:

### node1

Access MySQL server inside the container (password: mypass):
```
docker exec -it node1 mysql -uroot -p
```
Run these commands in server console:
```
SET @@GLOBAL.group_replication_bootstrap_group=1;
create user 'root'@'%';
GRANT ALL  ON * . * TO root@'%';
flush privileges;
change master to master_user='root' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```

### node2

Access MySQL server inside the container (password: mypass):
```
docker exec -it node2 mysql -uroot -p
```
Run these commands in server console:
```
change master to master_user='root' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```

### node3

Access MySQL server inside the container (password: mypass):
```
docker exec -it node3 mysql -uroot -p
```
Run these commands in server console:
```
change master to master_user='root' for channel 'group_replication_recovery';
START GROUP_REPLICATION;
SELECT * FROM performance_schema.replication_group_members;
```
By now, you should see:
![alt text](https://github.com/wagnerjfr/MySQLGroupReplication/blob/master/Docker-GR-Image3.png)

## Stop containers, remove created network and image

In another terminal, run the below commands to:

#### Stop running container(s):
```
docker stop node1 node2 node3
```
#### Remove the data directories created (they are located in the folder were the containers were run):
```
sudo rm -rf d0 d1 d2
```
#### Remove the created network:
```
docker network rm group1
```
#### Remove the MySQL 8 image:
```
$ docker rmi mysql/mysql-server:8.0
```
