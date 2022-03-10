#!/bin/sh

echo "syncer:$SYNC_PASSWORD" | chpasswd

# authorized_keys is mounted here (via docker-compose)
test -d ~/.ssh || mkdir ~/.ssh

/usr/sbin/sshd -D -e "$@"