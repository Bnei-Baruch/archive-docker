#!/usr/bin/env bash
set +e
set -x

# Setup elastic backup
curl -XPUT 'http://localhost:9200/_snapshot/backup' -H 'Content-Type: application/json' -d '{
    "type": "fs",
    "settings": {
        "location": "/backup/elastic",
        "compress": true
    }
}'
