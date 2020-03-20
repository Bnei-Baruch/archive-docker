#!/bin/sh

ssh-keygen -A

echo "syncer:$SYNC_PASSWORD" | chpasswd

exec /usr/sbin/sshd -D -e "$@"
