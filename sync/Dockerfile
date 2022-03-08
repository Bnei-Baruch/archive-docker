FROM alpine:latest

LABEL maintainer="edoshor@gmail.com"

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        openssh && \
    rm -rf /var/cache/apk/*

RUN adduser -D syncer

VOLUME ["/data"]

EXPOSE 2222

ADD start.sh /start.sh
CMD /start.sh
