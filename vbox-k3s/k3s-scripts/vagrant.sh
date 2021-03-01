#!/usr/bin/env bash
# for k3s vagrant / mojaloop installation 
# can I install just account lookup and have this run ?  Maybe too much work ??
# make this multi-node 
# TLS for NGINX
# Valid certificates




# install k3s w/o traefik (check on this maybe Mojaloop already has ingress)
# as I am going to install nginx 
#curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-backend=none \
      --cluster-cidr=192.168.0.0/16 --disable-network-policy --disable=traefik" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.bashrc
echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc # add autocomplete permanently to your bash shell.


#install docker.io
apt install docker.io -y 
groupadd docker
usermod -a -G docker vagrant
systemctl start docker

echo "install  version 10+ of node"
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash
apt-get install -y nodejs

echo "installing packages"
apt install git -y
apt install npm -y
apt install jq -y
npm install npm@latest -g
npm install -g newman

echo "clone postman tests for Mojaloop"
rm -rf /vagrant/postman 
git clone --branch $POSTMAN_TAG https://github.com/mojaloop/postman.git /vagrant/postman 

# install helm
echo "installing helm "
echo "ID is `id`"
cd $HOME
curl -o $HOME/helm.tar.gz https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz
cat helm.tar.gz | gzip -d -c | tar xf -
cp $HOME/linux-amd64/helm /usr/local/bin 

echo "Mojaloop: add helm repos ..." 
su - vagrant -c "helm repo add mojaloop http://mojaloop.io/helm/repo/"
su - vagrant -c "helm repo add stable https://charts.helm.sh/stable"
su - vagrant -c "helm repo add incubator https://charts.helm.sh/incubator"
su - vagrant -c "helm repo add kiwigrid https://kiwigrid.github.io"
su - vagrant -c "helm repo add elastic https://helm.elastic.co"
su - vagrant -c "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx"
su - vagrant -c "helm repo update"
su - vagrant -c "helm list"
su - vagrant -c "helm repo list"


#install nginx 
# install ingress ?  Not sure maybe use mojaloop's ingress -- check on this 
#  
su - vagrant -c "helm install ingress-nginx ingress-nginx/ingress-nginx"

# install calico 
su - vagrant -c "kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml"
su - vagrant -c "kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml"
