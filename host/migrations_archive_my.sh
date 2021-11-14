#!/usr/bin/env bash
set -e
#set -x


tmp_dir=$(mktemp -d -t migrations-"$(date +%Y-%m-%d-%H-%M-%S)"-XXXXXXXXXX)
echo "$tmp_dir"

eval "$(shdotenv -d docker)"
dummy="dummy_archive_my"
docker create --name ${dummy} bneibaruch/archive_my:${ARCHIVE_MY_VERSION}
docker cp ${dummy}:/app/migrations "$tmp_dir"
ls -laR $tmp_dir
docker run --rm -v "$tmp_dir/migrations/mydb":/migrations --network archive-docker_backend migrate/migrate -path=/migrations/ -database postgres://$MY_USER:$MY_PASSWORD@postgres_my/mydb?sslmode=disable up
docker rm -f ${dummy}
rm -rf "$tmp_dir"
