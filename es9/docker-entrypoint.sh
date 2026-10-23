#!/bin/bash
set -e

# Create FS backup repository with correct permissions
mkdir -p /backup/es9
chown -R elasticsearch:root /backup/es9

exec /usr/local/bin/elastic-entrypoint.sh "$@"
