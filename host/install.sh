#!/usr/bin/env bash
set +e
set -x

yum update -y

# repo for git 2.x
yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm

# Install Docker CE
yum install -y \
  yum-utils \
  device-mapper-persistent-data \
  lvm2 \
  git \
  jq \
  httpd-tools

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
docker version

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Download installation sources
git clone https://github.com/Bnei-Baruch/archive-docker.git

touch archive-docker/.env
echo "fill in .env file and continue to post-install.sh"
