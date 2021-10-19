#!/usr/bin/env bash
# for k3s vagrant / mojaloop installation 
# can I install just account lookup and have this run ?  Maybe too much work ??
# make this multi-node 
# TLS for NGINX
# Valid certificates

# Globals 
K8S_VERSION="v1.22"


if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# install docker on k3s node (see #https://rancher.com/docs/k3s/latest/en/advanced/#using-docker-as-the-container-runtime)
#curl https://releases.rancher.com/install-docker/19.03.sh | sh

# install k3s w/o traefik as we install nginx below
# will also install calico in future releases 
# to clean-up and uninstall use : /usr/local/bin/k3s-uninstall.sh
# curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
#                                INSTALL_K3S_CHANNEL="v1.20" \
#                                INSTALL_K3S_EXEC=" --no-deploy traefik " sh  

#without docker 
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                               INSTALL_K3S_CHANNEL=$K8S_VERSION \
                               INSTALL_K3S_EXEC=" --no-deploy traefik " sh                                 

# This install version is for enabling podsecurity policies 
# again this is future work now (Aug 2021)
# curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="600" \
#                                INSTALL_K3S_EXEC="--no-deploy traefik \
#                                --kube-apiserver-arg=enable-admission-plugins=\
# 		                   NodeRestriction,PodSecurityPolicy,ServiceAccount"  sh -

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/k3s.yaml
chown vagrant /home/vagrant/k3s.yaml
chmod 600 /home/vagrant/k3s.yaml 
echo "source .bashrc" >> /home/vagrant/.bash_profile 
echo "export KUBECONFIG=/home/vagrant/k3s.yaml" >> /home/vagrant/.bashrc
echo "export KUBECONFIG=/home/vagrant/k3s.yaml" >> /home/vagrant/.bash_profile
echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc # add autocomplete permanently to your bash shell.
echo "alias k=kubectl " >> /home/vagrant/.bashrc
echo "complete -F __start_kubectl k " >> /home/vagrant/.bashrc
echo 'alias ksetns="kubectl config set-context --current --namespace"'  >> /home/vagrant/.bashrc
echo "alias ksetuser=\"kubectl config set-context --current --user\""  >> /home/vagrant/.bashrc

#install kubens & kubectx (to facilitate namespace & config switching)
curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubens_v0.9.4_linux_x86_64.tar.gz | gzip -d -c | tar xf -
mv ./kubens /usr/local/bin
curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx_v0.9.4_linux_x86_64.tar.gz | gzip -d -c | tar xf -
mv ./kubectx /usr/local/bin

# install kustomize
curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
mv ./kustomize /usr/local/bin

#install docker.io
# apt update -y 
# apt install docker.io -y 
# groupadd docker
# usermod -a -G docker vagrant
# systemctl start docker

# echo "install  version 10+ of node"
# curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash
# apt-get install -y nodejs

echo "installing packages"
apt install git -y
apt install bash-completion
#apt install npm -y
apt install jq -y
#npm install npm@latest -g
#npm install -g newman

# install helm
echo "installing helm "
echo "ID is `id`"
cd /tmp
curl -L -s -o ./helm.tar.gz https://get.helm.sh/helm-v3.6.2-linux-amd64.tar.gz
cat ./helm.tar.gz | gzip -d -c | tar xf -
cp ./linux-amd64/helm /usr/local/bin 

echo "Mojaloop: add helm repos ..." 
su - vagrant -c "helm repo add mojaloop http://mojaloop.io/helm/repo/"
#su - vagrant -c "helm repo add stable https://charts.helm.sh/stable"
#su - vagrant -c "helm repo add incubator https://charts.helm.sh/incubator"
su - vagrant -c "helm repo add kiwigrid https://kiwigrid.github.io"
su - vagrant -c "helm repo add elastic https://helm.elastic.co"
su - vagrant -c "helm repo add bitnami https://charts.bitnami.com/bitnami"
su - vagrant -c "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx"
#su - vagrant -c "helm repo add kong https://charts.konghq.com" 
su - vagrant -c "helm repo update"
#su - vagrant -c "export KUBECONFIG=~/k3s.yaml; helm list"
su - vagrant -c "helm list"
su - vagrant -c "helm repo list"


#install nginx => beware which one  
# for k8s = 1.22 need kubernetes ingress 1.0.4 => chart version 4.0.6
# for k8s < v1.22 need kubernetes nginx ingress 0.47.0 
# see: https://kubernetes.io/blog/2021/07/26/update-with-ingress-nginx/
# see also https://kubernetes.github.io/ingress-nginx/
# use helm search repo -l nginx to find the chart version that corresponds to ingress release 0.47.x
# also we wait for 600secs here to ensure nginx controller is up
su - vagrant -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx/ingress-nginx --version=\"3.33.0\"  "

echo "**** Infrastructure to install and run Mojaloop should now be installed and running ****"
### notes and things for later #####$

# install calico 
#su - vagrant -c "kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml"
#su - vagrant -c "kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml"

# optional install docker , here just for reference for the moment
# see https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04
# apt update
# sudo apt install apt-transport-https ca-certificates curl software-properties-common
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
# apt update
# apt-cache policy docker-ce
# apt install docker-ce



