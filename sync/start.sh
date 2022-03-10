#!/bin/sh

echo "syncer:$SYNC_PASSWORD" | chpasswd

# authorized_keys is mounted here (via docker-compose)
test -d ~/.ssh || mkdir ~/.ssh

# copy generated host keys (apk install) into a persisted volume (/keys)
for f in /etc/ssh/*key*; do
    test -e "/keys/${f##*/}" || cp "$f" "/keys/${f##*/}"
done

/usr/sbin/sshd -D -e "$@"