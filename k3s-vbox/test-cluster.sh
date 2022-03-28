#!/bin/sh

# Globals 
K8S_VERSION="v1.22"

# Using calico as the CNI
# this seems to have issues with both DNS and with pod- to pod communications 
# 
# k3d cluster create mojaclus --port 8080:80@loadbalancer --port 8443:443@loadbalancer --k3s-server-arg '--flannel-backend=none' --k3s-server-arg '--no-deploy=traefik' \
#       --volume "/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml" \
#       --volume "/home/vagrant/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml" 


# use default flannel CNI and leave out calico all together for the moment.
# still use nginx ingress
# Ok can ping pod to pod withing same node , but still have DNS issues see @https://github.com/rancher/k3d/issues/209
# k3d cluster create mojaclus --port 8080:80@loadbalancer --port 8443:443@loadbalancer --k3s-server-arg '--no-deploy=traefik' \
#       --volume "/home/vagrant/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml" \
#       --volume "/run/systemd/resolve/resolv.conf:/etc/resolv.conf"

# Use docker so i can avoid the containerd issue
 curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                               INSTALL_K3S_CHANNEL=$K8S_VERSION \
                               INSTALL_K3S_EXEC=" --no-deploy traefik  --docker " sh                               
