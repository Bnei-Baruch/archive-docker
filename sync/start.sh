#!/bin/sh

ssh-keygen -A

echo "syncer:$SYNC_PASSWORD" | chpasswd

test -d ~/.ssh || mkdir ~/.ssh

/usr/sbin/sshd -D -p 2222 -e "$@"