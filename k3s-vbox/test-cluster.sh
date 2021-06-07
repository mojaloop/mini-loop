#!/bin/sh

k3d cluster create mojaclus --port 8080:80@loadbalancer --port 8443:443@loadbalancer --k3s-server-arg '--flannel-backend=none' --k3s-server-arg '--no-deploy=traefik' \
      --volume "/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml" \
      --volume "/home/vagrant/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml" 
