FROM docker.elastic.co/elasticsearch/elasticsearch:6.8.6

LABEL maintainer="edoshor@gmail.com"

RUN mkdir -p /usr/share/elasticsearch/config/hunspell/he_IL && \
    wget -O /usr/share/elasticsearch/config/hunspell/he_IL/he_IL.aff https://raw.githubusercontent.com/elastic/hunspell/master/dicts/he_IL/he_IL.aff && \
    wget -O /usr/share/elasticsearch/config/hunspell/he_IL/he_IL.dic https://raw.githubusercontent.com/elastic/hunspell/master/dicts/he_IL/he_IL.dic && \
    wget -O /usr/share/elasticsearch/config/hunspell/he_IL/settings.yml https://raw.githubusercontent.com/elastic/hunspell/master/dicts/he_IL/settings.yml && \
    chown -R elasticsearch:root /usr/share/elasticsearch/config/hunspell


RUN mv /usr/local/bin/docker-entrypoint.sh /usr/local/bin/elastic-entrypoint.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

VOLUME ["/backup"]