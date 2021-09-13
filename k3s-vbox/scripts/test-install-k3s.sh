#!/usr/bin/env bash
# test install and config of k3s

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                               INSTALL_K3S_EXEC="--no-deploy traefik \
                               --kube-apiserver-arg=enable-admission-plugins=\
		                        NodeRestriction,ServiceAccount"  sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/k3s.yaml
chown vagrant /home/vagrant/k3s.yaml
