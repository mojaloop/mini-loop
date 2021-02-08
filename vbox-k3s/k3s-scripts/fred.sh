#!/usr/bin/env bash

# install k3s
curl -sfL https://get.k3s.io | sh -
chmod 644 /etc/rancher/k3s/k3s.yaml

#install docker.io
apt install docker.io -y 


groupadd docker
usermod -a -G docker vagrant
systemctl start docker



