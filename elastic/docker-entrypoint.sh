#!/bin/bash
set -e

# Create FS backup repository with correct permissions
mkdir -p /backup/elastic
chown -R elasticsearch:root /backup/elastic

exec /usr/local/bin/elastic-entrypoint.sh "$@"
