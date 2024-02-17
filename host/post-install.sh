#!/usr/bin/env bash
set +e
set -x

# before you start:
# * add your instance ip to mdb postgres pg_hba.conf file with replication permission
# * reload it in psql (no restart needed) via SELECT pg_reload_conf();
# * While you're inside psql: create a replication slot via select pg_create_physical_replication_slot('my_replication_slot_name');
# * add this slot name to .env MDB_PRIMARY_SLOTNAME

# Internal hosts
cat host/etc_hosts >> /etc/hosts

# required for elastic in docker
sysctl -w vm.max_map_count=262144

# bring up services
docker compose pull
docker compose up -d

echo "initial postgres replication takes time, watch with top to see that pg_basebackup is not consuming any cpu"
sleep 600

# Create ssh host keys for sync
ssh-keygen -q -N "" -t rsa -b 4096 -f sync/host_keys/ssh_host_rsa_key
ssh-keygen -q -N "" -t ecdsa -f sync/host_keys/ssh_host_ecdsa_key
ssh-keygen -q -N "" -t ed25519 -f sync/host_keys/ssh_host_ed25519_key

# create .htpasswd for serving backup over http
grep SYNC_PASSWORD .env # copy paste this into next interactive command
htpasswd -c nginx/.htpasswd sync

# prefix environment in configs on environment other than production
# .env -> KMEDIA_MDB_VERSION = <env>
# .env -> MDB_ADMIN_VERSION = <env>
# docker-compose.yml -> mdb_links.BASE_URL = https://<env>-cdn.kabbalahmedia.info/
# archive_backend/config.toml -> nats.client-id = "<env>-archive-backend-docker"
# archive_backend/config.toml -> nats.durable-name = "<env>-archive-backend-events"
# feed_api/config.toml -> nats.client-id = "<env>-feed-api"
# feed_api/config.toml -> nats.durable-name = "<env>-feed-api-events"
# nginx/conf.d/links.conf -> server_name <env>-cdn.kabbalahmedia.info;


# DB migrations tools
wget https://github.com/ko1nksm/shdotenv/releases/latest/download/shdotenv -O /usr/local/bin/shdotenv
chmod +x /usr/local/bin/shdotenv
wget https://github.com/elwinar/rambler/releases/download/v5.4.0/rambler-linux-amd64 -O /usr/local/bin/rambler
chmod +x /usr/local/bin/rambler

# bring up feed-api
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml pull
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml up -d
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml stop feed_api

docker compose exec -T postgres_mdb /bin/bash -c 'PGPASSWORD=$MDB_PASSWORD pg_dump -h localhost -U $MDB_USER -w --no-owner --clean --format=plain -d mdb > /backup/mdb_dump_no_create.sql'
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database mdb;" '
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database chronicles;" '
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database data_models;" '
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d mdb < /backup/mdb_dump_no_create.sql'
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d mdb -c "create extension dblink" '
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d chronicles -c "create extension dblink" '
#docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d data_models -c "create extension dblink" '

host/migrations_feed_api.sh
docker compose -f docker-compose.yml -f docker-compose-feed_api.yml start feed_api

# bring up archive-my
docker compose -f docker-compose.yml -f docker-compose-my.yml pull
docker compose -f docker-compose.yml -f docker-compose-my.yml up -d
docker compose -f docker-compose.yml -f docker-compose-my.yml stop archive_my

docker compose -f docker-compose.yml -f docker-compose-my.yml exec -T postgres_my /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database mydb;" '

# restore dump
# get a dump on old server (TODO edo: automate dump and back it up)
docker-compose exec -T postgres_my /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h localhost -U $POSTGRES_USER -w --no-owner --clean --format=plain -d mydb > /backup/mydb_dump_no_create.sql'
docker cp archive-docker_postgres_my_1:/backup/mydb_dump_no_create.sql .

# on new vm
scp archive.local:/root/archive-docker/mydb_dump_no_create.sql .
docker cp mydb_dump_no_create.sql archive-docker-postgres_my-1:/backup/mydb_dump_no_create.sql
docker compose -f docker-compose.yml -f docker-compose-my.yml exec -T postgres_my /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d mydb < /backup/mydb_dump_no_create.sql'

host/migrations_archive_my.sh

docker compose -f docker-compose.yml -f docker-compose-my.yml start archive_my
docker compose up -d --build --no-deps nginx

# Setup elastic backup
curl -XPUT 'http://localhost:9200/_snapshot/backup' -H 'Content-Type: application/json' -d '{
    "type": "fs",
    "settings": {
        "location": "/backup/elastic",
        "compress": true
    }
}'

# reindex elastic
# don't "reindex.sh", watch the logs and avoid sending error emails
mkdir -p logs/es
docker compose exec -dt archive_backend sh -c "./archive-backend index >> /tmp/index.log 2>&1"
docker compose exec -dt archive_backend sh -c "./archive-backend index_grammars >> /tmp/index.log 2>&1"
docker compose exec -dt archive_backend sh -c "./archive-backend update_synonyms >> /tmp/index.log 2>&1"

# make sure nginx is up correctly here

# re-run everything
docker compose -f docker-compose.yml -f docker-compose-events.yml -f docker-compose-my.yml -f docker-compose-feed_api.yml up -d

# scale kmedia-mdb
docker compose up -d --no-build --scale kmedia_mdb=3


# Fetch on-disk assets
# TODO (edo): this should change once sync mechanism is working in suitcase. When it is, use that
# on old machine
cd /tmp
mkdir -p archive/assets
cd archive/assets/
docker cp archive-docker_nginx_1:/sites/assets/logos .
docker cp archive-docker_nginx_1:/sites/assets/lessons .
docker cp archive-docker_nginx_1:/sites/assets/help .

# on new machine
372  cd /tmp
374  mkdir archive
375  cd archive/
379  rsync -avzhe ssh <old-machine>:/tmp/archive/assets .
387  docker cp assets/logos archive-docker-archive_backend-1:/assets
390  docker cp assets/help archive-docker-archive_backend-1:/assets
391  docker cp assets/lessons archive-docker-archive_backend-1:/assets

# ssh key for sync
# https://github.com/Bnei-Baruch/archive-suitcase-docker/blob/master/host/post-install.sh#L11
# mkdir -p assets
# rsync -avzhe ssh --delete --exclude='generated' --exclude='unzip' production-archive:/data/assets/ assets/
# docker run -it --rm --volume archive-docker_assets:/data --volume $(pwd)/assets:/src busybox cp -r /src/. /data
# rm -rf assets


# install cron jobs
sed "s|<INSTALL_DIR>|$(pwd)|g" host/archive.cron.txt > /etc/cron.d/archive

# make sure crond.service is started and enabled
systemctl status crond
systemctl enable crond
systemctl start crond

# monitoring
# set ./monitoring/config.river - loki credendtials
# set ./monitoring/postgres_exporter.yml - readonly credentials for postgres_exporter (.env)



# CI/CD reminder
echo "REMINDER: setup ssh access for CI/CD agents"

# easier life. put this in ~/.bashrc
# alias docker-compose='docker-compose -f ~/archive-docker/docker-compose.yml -f ~/archive-docker/docker-compose-events.yml -f ~/archive-docker/docker-compose-feed_api.yml -f ~/archive-docker/docker-compose-my.yml'
