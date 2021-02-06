#!/usr/bin/env bash

# install k3s
curl -sfL https://get.k3s.io | sh -
chmod 644 /etc/rancher/k3s/k3s.yaml

#install docker.io
apt install docker.io -y 
groupadd docker
usermod -a -G docker vagrant
systemctl start docker

# install helm
# install ingress ?  Not sure maybe use mojaloop's ingress -- check on this
# can I install just account lookup and have this run ?  Maybe too much work ??
# make this multi-node 

echo "ID is `id`"
cd $HOME
curl -o $HOME/helm.tar.gz https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz
cat helm.tar.gz | gzip -d -c | tar xf -
cp $HOME/linux-amd64/helm /usr/local/bin



