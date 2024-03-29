#!/usr/bin/env bash
set -e
#set -x


tmp_dir=$(mktemp -d -t migrations-"$(date +%Y-%m-%d-%H-%M-%S)"-XXXXXXXXXX)
echo "$tmp_dir"


eval "$(shdotenv -d docker)"
dummy="dummy_feed_api"
docker create --name ${dummy} bneibaruch/feed_api:${FEED_API_VERSION}
docker cp ${dummy}:/app/migrations "$tmp_dir"
ls -laR $tmp_dir


docker run --rm -v "$tmp_dir/migrations/chronicles":/migrations --network archive-docker_backend migrate/migrate -path=/migrations/ -database postgres://$FEED_USER:$FEED_PASSWORD@postgres_feed/chronicles?sslmode=disable up
docker run --rm -v "$tmp_dir/migrations/data_models":/migrations --network archive-docker_backend migrate/migrate -path=/migrations/ -database postgres://$FEED_USER:$FEED_PASSWORD@postgres_feed/data_models?sslmode=disable up

export RAMBLER_DATABASE=mdb
export RAMBLER_DIRECTORY="$tmp_dir/migrations/mdb"
export RAMBLER_DRIVER=postgresql
export RAMBLER_HOST=localhost
export RAMBLER_PORT=5433
export RAMBLER_TABLE=migrations
export RAMBLER_USER=$FEED_USER
export RAMBLER_PASSWORD=$FEED_PASSWORD
rambler apply -a


docker rm -f ${dummy}
rm -rf "$tmp_dir"
