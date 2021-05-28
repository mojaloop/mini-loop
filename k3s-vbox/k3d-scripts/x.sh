#!/usr/bin/env bash
# for multinode k3d/k3s vagrant / mojaloop installation 
# TLS for NGINX
# Valid certificates


cat << !EOF > /home/vagrant/helm-ingress-nginx.yaml 
# see https://rancher.com/docs/k3s/latest/en/helm/
# see https://github.com/kubernetes/ingress-nginx/tree/master/charts/ingress-nginx
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: ingress-controller-nginx
  namespace: kube-system
spec:
  repo: https://kubernetes.github.io/ingress-nginx
  chart: ingress-nginx
  version: 3.31.0
  targetNamespace: kube-system
!EOF
chown vagrant /home/vagrant/helm-ingress-nginx.yaml 

set -x 
# # create a k3d cluster with nginx ingress and using calico CNI and networkpolicy
su - vagrant -c "k3d cluster create moja --k3s-server-arg '--flannel-backend=none' --k3s-server-arg '--no-deploy=traefik' \
      --volume \"/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml\" \
      --volume \"/home/vagrant/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml\" " 
