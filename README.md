# Docker-Compose Archive
This is how we deploy the services composing the archive in various environments.




## Installation

Assuming a CentOS 7 host with docker installed.

Make sure the master postgres MDB instance has your IP listed for replication.
Make sure nats streaming is accessible from your machine.

Here should follow instructions on how to setup on a fresh machine.
Probably something along the lines of:

```shell script
curl -sL https://raw.githubusercontent.com/Bnei-Baruch/archive-docker/master/host/install.sh | bash -s 

cd archive-docker
vi .env

host/post-install.sh
```


# Operations
**Start the System**

```shell script
docker-compose up -d
```

**Inspect a service logs**
 
```shell script
docker-compose logs -f <SERVICE> 
```

Nginx access and error logs per service is saved on an attached volume. To access these files use a utility container:
```shell script
docker run -it --rm --volume archive-docker_nginx_data:/data busybox 
```

**Reload A Service**

After a service code or environment has changed. 
```shell script
docker-compose pull <SERVICE>
docker-compose up -d --no-deps --build <SERVICE> 
```
TODO: find out why nginx restart is required to have the IP of the newly updated service container.


**Run a one-off command**

To run a one-off command use [docker-compose exec](https://docs.docker.com/compose/reference/exec/). 
Using [docker-compose run](https://docs.docker.com/compose/reference/run/) seems to mess up with DNS resolution as well ?!  

For example: 
```shell script
docker-compose exec archive_backend ./archive-backend index
```


**psql for MDB**

To start a psql session with MDB read replica 

```shell script
(export $(grep MDB .env | xargs) ; docker-compose exec postgres_mdb psql  "postgres://$MDB_USER:$MDB_PASSWORD@localhost/mdb?sslmode=disable")
```
