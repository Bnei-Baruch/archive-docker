#!/usr/bin/env bash
set +e
set -x

dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf upgrade --refresh
dnf -y install \
  git \
  jq \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin \
  httpd-tools

systemctl --now enable docker
docker version

# Download installation sources
git clone https://github.com/Bnei-Baruch/archive-docker.git

touch archive-docker/.env
echo "fill in .env file and continue to post-install.sh"
