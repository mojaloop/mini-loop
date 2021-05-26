#!/usr/bin/env bash
# for k3s vagrant / mojaloop installation 
# can I install just account lookup and have this run ?  Maybe too much work ??
# make this multi-node 
# TLS for NGINX
# Valid certificates

POSTMAN_TAG="v11.0.0"

# install k3s w/o traefik (check on this maybe Mojaloop already has ingress)
# as I am going to install nginx 
#curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                               INSTALL_K3S_EXEC="--no-deploy traefik \
                               --kube-apiserver-arg=enable-admission-plugins=\
		                   NodeRestriction,PodSecurityPolicy,ServiceAccount"  sh -
#curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
#      INSTALL_K3S_EXEC="--no-deploy traefik " sh 
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/k3s.yaml
chown vagrant /home/vagrant/k3s.yaml
chmod 600 /home/vagrant/k3s.yaml 
echo "export KUBECONFIG=/home/vagrant/k3s.yaml" >> /home/vagrant/.bashrc
echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc # add autocomplete permanently to your bash shell.
echo "alias k=kubectl " >> /home/vagrant/.bashrc
echo "complete -F __start_kubectl k " >> /home/vagrant/.bashrc
echo 'alias ksetns="kubectl config set-context --current --namespace"'  >> /home/vagrant/.bashrc
echo "alias ksetuser=\"kubectl config set-context --current --user\""  >> /home/vagrant/.bashrc

# install kustomize
curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
mv ./kustomize /usr/local/bin

# add the mojaloop endpoints per doc at 
echo "add /etc/hosts entries for local access to mojaloop endpoints" 
ENDPOINTSLIST=(127.0.0.1    localhost forensic-logging-sidecar.local central-kms.local central-event-processor.local email-notifier.local central-ledger.local 
central-settlement.local ml-api-adapter.local account-lookup-service.local 
 account-lookup-service-admin.local quoting-service.local moja-simulator.local 
 central-ledger central-settlement ml-api-adapter account-lookup-service 
 account-lookup-service-admin quoting-service simulator host.docker.internal)
export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
ping  -c 2 account-lookup-service-admin 

#install docker.io
# apt update -y 
# apt install docker.io -y 
# groupadd docker
# usermod -a -G docker vagrant
# systemctl start docker

# installing k3d (so we can have multi-node)
# wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
# 

echo "install  version 10+ of node"
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash
apt-get install -y nodejs

echo "installing packages"
apt install git -y
apt install bash-completion
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
su - vagrant -c "helm repo add bitnami https://charts.bitnami.com/bitnami"
su - vagrant -c "helm repo add codecentric https://codecentric.github.io/helm-charts"
su - vagrant -c "helm repo add nginx-stable https://helm.nginx.com/stable"
su - vagrant -c "helm repo add kong https://charts.konghq.com" 
su - vagrant -c "helm repo update"
su - vagrant -c "export KUBECONFIG=~/k3s.yaml; helm list"
su - vagrant -c "helm repo list"


#install nginx 
# install ingress ?  Not sure maybe use mojaloop's ingress -- check on this 
#  
#su - vagrant -c "export KUBECONFIG=~/k3s.yaml; \
#      helm install ml-ingres nginx-stable/nginx-ingress"

# install calico 
#su - vagrant -c "kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml"
#su - vagrant -c "kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml"

# install pod security policies 





# optional install docker , here just for reference for the moment
# see https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04
# apt update
# sudo apt install apt-transport-https ca-certificates curl software-properties-common
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
# apt update
# apt-cache policy docker-ce
# apt install docker-ce

# then you can install a multi-node k3s cluster with k3d
# see : https://www.suse.com/c/introduction-k3d-run-k3s-docker-src/
# see : https://en.sokube.ch/post/k3s-k3d-k8s-a-new-perfect-match-for-dev-and-test-1

