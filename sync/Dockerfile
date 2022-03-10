FROM alpine:latest

LABEL maintainer="edoshor@gmail.com"

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        openssh \
        rsync && \
    rm -rf /var/cache/apk/*

RUN adduser -D syncer

VOLUME ["/data"]
VOLUME ["/keys"]

EXPOSE 2222

ADD sshd_config /etc/ssh/sshd_config
ADD start.sh /start.sh
CMD /start.sh
