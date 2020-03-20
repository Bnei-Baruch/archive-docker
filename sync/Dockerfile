FROM alpine:latest

LABEL maintainer="edoshor@gmail.com"

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        openssh && \
    rm -rf /var/cache/apk/*

RUN adduser -D syncer

COPY docker-entrypoint.sh /usr/local/bin

VOLUME ["/data"]

EXPOSE 22

ENTRYPOINT ["docker-entrypoint.sh"]
