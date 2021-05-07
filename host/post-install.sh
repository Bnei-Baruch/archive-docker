#!/usr/bin/env bash
set +e
set -x

# Internal hosts
cat host/etc_hosts >> /etc/hosts

# required for elastic in docker
sysctl -w vm.max_map_count=262144

# bring up services
docker-compose -f docker-compose.yml -f docker-compose-events.yml pull
docker-compose up -d
docker-compose -f docker-compose.yml -f docker-compose-events.yml up -d

# TODO: events above is environment optional, otherwise we could just:
# docker-compose pull && docker-compose up -d


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
docker-compose exec archive_backend ./archive-backend index

# re-run everything
docker-compose -f docker-compose.yml -f docker-compose-events.yml up -d

# scale kmedia-mdb
docker-compose up -d --no-build --scale kmedia_mdb=3

# install cron jobs
sed "s|<INSTALL_DIR>|$(pwd)|g" host/archive.cron.txt > /etc/cron.d/archive

# CI/CD reminder
echo "REMINDER: setup ssh access for CI/CD agents"
