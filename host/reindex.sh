#!/usr/bin/env bash

set +e
set -x

BASE_DIR="/root/archive-docker"
TIMESTAMP="$(date '+%Y%m%d%H%M%S')"
LOG_FILE="$BASE_DIR/logs/es/reindex_$TIMESTAMP.log"

cd ${BASE_DIR}

docker compose -f docker-compose.yml -f docker-compose-events.yml stop events

docker compose exec archive_backend ./archive-backend index >> ${LOG_FILE} 2>&1
docker compose exec archive_backend ./archive-backend index_grammars >> ${LOG_FILE} 2>&1
docker compose exec archive_backend ./archive-backend update_synonyms >> ${LOG_FILE} 2>&1

curl -X POST "localhost:9200/_refresh"

docker compose -f docker-compose.yml -f docker-compose-events.yml start events


WARNINGS="$(egrep -c "level=(warning|error)" ${LOG_FILE})"
#
#if [ "$WARNINGS" != "0" ];then
#	echo "Errors in reindex" | mail -s "ERROR: ES reindex" -r "mdb@bbdomain.org" -a ${LOG_FILE} edoshor@gmail.com kolmanv@gmail.com yurihechter@gmail.com
#fi

# Cleanup old logs (older then week).
find ${BASE_DIR}/logs/es -name "reindex_*.log" -type f -mtime +7 -exec rm -f {} \;

if [ "$WARNINGS" != "0" ];then
    echo "Errors or Warnings found."
    exit 1
else
 	echo "No warnings"
	exit 0
fi

