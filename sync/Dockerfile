FROM alpine:latest

LABEL maintainer="edoshor@gmail.com"

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        rsync && \
    rm -rf /var/cache/apk/*

COPY ./rsyncd.conf /etc/

VOLUME ["/data"]

EXPOSE 873

CMD ["/usr/bin/rsync", "--no-detach", "--daemon"]
