FROM nginx:latest

LABEL maintainer="edoshor@gmail.com"

RUN apt-get update && \
  apt-get install -y cron logrotate && \
  apt-get clean && \ 
  rm -rf /var/lib/apt/lists/*

COPY nginx.conf /etc/nginx/nginx.conf
RUN rm -f /etc/nginx/conf.d/*
COPY conf.d/ /etc/nginx/conf.d
COPY logrotate.conf /etc/logrotate.d/nginx

VOLUME ["/data"]

CMD service cron start && nginx -g 'daemon off;'

