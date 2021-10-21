#!/usr/bin/env bash
set -e
#set -x


tmp_dir=$(mktemp -d -t migrations-"$(date +%Y-%m-%d-%H-%M-%S)"-XXXXXXXXXX)
echo "$tmp_dir"

docker cp archive-docker_archive_my_1:/app/migrations "$tmp_dir"

eval "$(shdotenv -d docker)"

docker run --rm -v "$tmp_dir/migrations/mydb":/migrations --network archive-docker_backend migrate/migrate -path=/migrations/ -database postgres://$MY_USER:$MY_PASSWORD@postgres_my/mydb?sslmode=disable up

rm -rf "$tmp_dir"
