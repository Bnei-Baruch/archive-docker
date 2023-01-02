#!/usr/bin/env bash
set +e
set -x

# before you start:
# * add your instance ip to mdb postgres pg_hba.conf file with replication permission
# * reload it in psql (no restart needed) via SELECT pg_reload_conf();
# * While you're inside psql: create a replication slot via select pg_create_physical_replication_slot('my_replication_slot_name');
# * add this slot name to docker-compose.yml (TODO: move to .env)

# Internal hosts
cat host/etc_hosts >> /etc/hosts

# required for elastic in docker
sysctl -w vm.max_map_count=262144

# bring up services
docker-compose pull
docker-compose up -d

echo "initial postgres replication takes time, watch with top to see that pg_basebackup is not consuming any cpu"
sleep 600

# Create ssh host keys for sync
ssh-keygen -q -N "" -t rsa -b 4096 -f sync/host_keys/ssh_host_rsa_key
ssh-keygen -q -N "" -t ecdsa -f sync/host_keys/ssh_host_ecdsa_key
ssh-keygen -q -N "" -t ed25519 -f sync/host_keys/ssh_host_ed25519_key

# create .htpasswd for serving backup over http
grep SYNC_PASSWORD .env # copy paste this into next interactive command
htpasswd -c nginx/.htpasswd sync

# To fetch assets from production (if needed) you can mimic a suitcase's sync module
# ssh key for sync
# https://github.com/Bnei-Baruch/archive-suitcase-docker/blob/master/host/post-install.sh#L11
# mkdir -p assets
# rsync -avzhe ssh --delete --exclude='generated' --exclude='unzip' production-archive:/data/assets/ assets/
# docker run -it --rm --volume archive-docker_assets:/data --volume $(pwd)/assets:/src busybox cp -r /src/. /data
# rm -rf assets

# prefix environment in configs on environment other than production
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
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml pull
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml up -d
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml stop feed_api

docker-compose exec -T postgres_mdb /bin/bash -c 'PGPASSWORD=$MDB_PASSWORD pg_dump -U $MDB_USER -w --no-owner --clean --format=plain -d mdb > /backup/mdb_dump_no_create.sql'
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database mdb;" '
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database chronicles;" '
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database data_models;" '
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d mdb < /backup/mdb_dump_no_create.sql'
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d mdb -c "create extension dblink" '
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d chronicles -c "create extension dblink" '
#docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d data_models -c "create extension dblink" '

host/migrations_feed_api.sh
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml start feed_api

# bring up archive-my
docker-compose -f docker-compose.yml -f docker-compose-my.yml pull
docker-compose -f docker-compose.yml -f docker-compose-my.yml up -d
docker-compose -f docker-compose.yml -f docker-compose-my.yml stop archive_my

docker-compose exec -T postgres_my /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database mydb;" '

host/migrations_archive_my.sh

docker-compose -f docker-compose.yml -f docker-compose-my.yml start archive_my
docker-compose up -d --build --no-deps nginx

# Setup elastic backup
curl -XPUT 'http://localhost:9200/_snapshot/backup' -H 'Content-Type: application/json' -d '{
    "type": "fs",
    "settings": {
        "location": "/backup/elastic",
        "compress": true
    }
}'

# reindex elastic
# make sure nginx is up correctly here
mkdir -p logs/es
docker-compose exec archive_backend ./archive-backend index
docker-compose exec archive_backend ./archive-backend index_grammars
docker-compose exec archive_backend ./archive-backend update_synonyms

# bring up events
docker-compose -f docker-compose.yml -f docker-compose-events.yml pull
docker-compose -f docker-compose.yml -f docker-compose-events.yml up -d

# re-run everything
docker-compose -f docker-compose.yml -f docker-compose-events.yml up -d

# scale kmedia-mdb
docker-compose up -d --no-build --scale kmedia_mdb=3

# install cron jobs
sed "s|<INSTALL_DIR>|$(pwd)|g" host/archive.cron.txt > /etc/cron.d/archive

# CI/CD reminder
echo "REMINDER: setup ssh access for CI/CD agents"

# easier life. put this in ~/.bashrc
# alias docker-compose='docker-compose -f ~/archive-docker/docker-compose.yml -f ~/archive-docker/docker-compose-events.yml -f ~/archive-docker/docker-compose-feed_api.yml -f ~/archive-docker/docker-compose-my.yml'
