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

# Setup elastic backup
curl -XPUT 'http://localhost:9200/_snapshot/backup' -H 'Content-Type: application/json' -d '{
    "type": "fs",
    "settings": {
        "location": "/backup/elastic",
        "compress": true
    }
}'

# fetch assets
mkdir -p assets
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -q -t rsa -b 4096 -f ~/.ssh/id_rsa -C "archive@suitcase.bbdomain.org" -N ''
fi

# TODO: this will probably be different after production is docker
ssh-copy-id suitcase@app.archive.bbdomain.org
rsync -avzhe ssh --delete --exclude='generated' --exclude='unzip' suitcase@app.archive.bbdomain.org:/sites/assets/ assets

ls -larth assets
docker run -it --rm --volume archive-docker_assets:/data --volume $(pwd)/assets:/src busybox cp -r /src/. /data
rm -rf assets


# reindex elastic
mkdir -p logs/es
docker-compose exec archive_backend ./archive-backend index
docker-compose exec archive_backend ./archive-backend index_grammars
docker-compose exec archive_backend ./archive-backend update_synonyms

# bring up events
echo "Prefix nats.client_id and nats.durable-name with environment (if not production)"
docker-compose -f docker-compose.yml -f docker-compose-events.yml pull
docker-compose -f docker-compose.yml -f docker-compose-events.yml up -d

echo "Prefix base-url in mdb_links config.toml environment (if not production)"

# re-run everything
docker-compose -f docker-compose.yml -f docker-compose-events.yml up -d

# scale kmedia-mdb
docker-compose up -d --no-build --scale kmedia_mdb=3

# install cron jobs
sed "s|<INSTALL_DIR>|$(pwd)|g" host/archive.cron.txt > /etc/cron.d/archive

# CI/CD reminder
echo "REMINDER: setup ssh access for CI/CD agents"

# bring up feed-api
echo "Prefix nats.client_id and nats.durable-name with environment (if not production)"
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml pull
docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml up -d

docker-compose exec -T postgres_mdb /bin/bash -c 'PGPASSWORD=$MDB_PASSWORD pg_dump -U $MDB_USER -w --no-owner --clean --format=plain -d mdb > /backup/mdb_dump_no_create.sql'
docker-compose exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database mdb;" '
docker-compose exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database chronicles;" '
docker-compose exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -c "create database data_models;" '
docker-compose exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d mdb < /backup/mdb_dump_no_create.sql'
docker-compose exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d mdb -c "create extension dblink" '
docker-compose exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d chronicles -c "create extension dblink" '
docker-compose exec -T postgres_feed /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -w -d data_models -c "create extension dblink" '

# DB migrations related
wget https://github.com/ko1nksm/shdotenv/releases/latest/download/shdotenv -O /usr/local/bin/shdotenv
chmod +x /usr/local/bin/shdotenv
wget https://github.com/elwinar/rambler/releases/download/v5.4.0/rambler-linux-amd64 -O /usr/local/bin/rambler
chmod +x /usr/local/bin/rambler
host/migrations_feed_api.sh

docker-compose -f docker-compose.yml -f docker-compose-feed_api.yml restart feed_api