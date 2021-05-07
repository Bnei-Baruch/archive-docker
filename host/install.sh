#!/usr/bin/env bash
set +e
set -x

yum update -y

# Install Docker CE
yum install -y \
  yum-utils \
  device-mapper-persistent-data \
  lvm2

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum install -y docker-ce docker-ce-cli containerd.io

# Fix for old kernels (centos 7)
# https://forums.docker.com/t/dns-resolution-not-working-in-containers/36246
# https://www.weave.works/blog/racy-conntrack-and-dns-lookup-timeouts
echo 'OPTIONS="--dns-opt=use-vc"' >> /etc/sysconfig/docker
cat << EOT >> /etc/docker/daemon.json
{
  "dns-opts": ["use-vc"]
}
EOT

systemctl start docker
systemctl enable docker
docker version


# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version


# Download installation sources
yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yum -y install git2u-all
git clone https://github.com/Bnei-Baruch/archive-docker.git

touch archive-docker/.env
echo "fill in .env file and continue to post-install.sh"
