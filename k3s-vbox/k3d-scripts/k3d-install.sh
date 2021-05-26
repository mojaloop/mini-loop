#!/usr/bin/env bash
# for multinode k3d/k3s vagrant / mojaloop installation 
# TLS for NGINX
# Valid certificates


#install docker.io
# apt update -y 
# apt install docker.io -y 
# groupadd docker
# usermod -a -G docker vagrant
# systemctl start docker

# installing k3d (so we can have multi-node)
# wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

# create cluster with calico CNI
# see : https://en.sokube.ch/post/k3s-k3d-k8s-a-new-perfect-match-for-dev-and-test-1


wget -q https://raw.githubusercontent.com/rancher/k3d/main/docs/usage/guides/calico.yaml -P /home/vagrant/
# k3d cluster create calico --k3s-server-arg '--flannel-backend=none, --kube-apiserver-arg=enable-admission-plugins=NodeRestriction,PodSecurityPolicy,ServiceAccount' \
#      --volume "/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml" 

k3d cluster create calico --k3s-server-arg '--flannel-backend=none' --k3s-server-arg '--no-deploy=traefik' \
      --volume "$HOME/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml" 
      
