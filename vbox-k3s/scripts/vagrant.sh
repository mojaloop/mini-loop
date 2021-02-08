#!/usr/bin/env bash
# can I install just account lookup and have this run ?  Maybe too much work ??
# make this multi-node 


# install k3s w/o traefik (check on this maybe Mojaloop already has ingress)
# as I am going to install nginx 
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
chmod 644 /etc/rancher/k3s/k3s.yaml

#install docker.io
apt install docker.io -y 
groupadd docker
usermod -a -G docker vagrant
systemctl start docker

# echo "install  version 10+ of node"
# curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash
# apt-get install -y nodejs

# echo "installing packages"
# apt install git -y
# apt install npm -y
# npm install npm@latest -g
# npm install -g newman

# echo "clone postman tests for Mojaloop"
# rm -rf /vagrant/postman 
# git clone --branch $POSTMAN_TAG https://github.com/mojaloop/postman.git /vagrant/postman 

# install helm
echo "ID is `id`"
cd $HOME
curl -o $HOME/helm.tar.gz https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz
cat helm.tar.gz | gzip -d -c | tar xf -
cp $HOME/linux-amd64/helm /usr/local/bin 

echo "Mojaloop: add repos and deploy helm charts ..." 
su - vagrant -c "helm repo add mojaloop http://mojaloop.io/helm/repo/"
su - vagrant -c "helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator"
su - vagrant -c "helm repo add kiwigrid https://kiwigrid.github.io"
su - vagrant -c "helm repo add elastic https://helm.elastic.co"
su - vagrant -c "helm repo update"
su - vagrant -c "helm list"
su - vagrant -c "helm repo list"


#install nginx 
# install ingress ?  Not sure maybe use mojaloop's ingress -- check on this 
#  
