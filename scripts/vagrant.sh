#!/usr/bin/env bash
# install mojaloop using Lewis Daly's temporary version
# 18th April 20202

# set locations 
POSTMAN_TAG="v10.1.0"

echo "add /etc/hosts entries for local access to mojaloop endpoints" 
ENDPOINTSLIST=(127.0.0.1    localhost forensic-logging-sidecar.local central-kms.local central-event-processor.local email-notifier.local central-ledger.local 
central-settlement.local ml-api-adapter.local account-lookup-service.local 
 account-lookup-service-admin.local quoting-service.local moja-simulator.local 
 central-ledger central-settlement ml-api-adapter account-lookup-service 
 account-lookup-service-admin quoting-service simulator host.docker.internal)
export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
ping  -c 2 account-lookup-service-admin 

export KUBERNETES_RELEASE=1.18
export PATH=$PATH:/snap/bin
echo $PATH

echo "install  version 10+ of node"
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash
apt-get install -y nodejs

echo "installing packages"
apt install git -y
apt install npm -y
npm install npm@latest -g
npm install -g newman

echo "clone postman tests for Mojaloop"
chown vagrant /home/vagrant/.config 
chgrp vagrant /home/vagrant/.config
rm -rf /vagrant/postman 
git clone --branch $POSTMAN_TAG https://github.com/mojaloop/postman.git /vagrant/postman 

echo "Mojaloop: run update ..."
apt update

echo "Mojaloop: installing snapd ..."
apt install snapd -y

# TODO; ${RELEASE} is not defined
echo "Mojaloop: installing microk8s release $RELEASE ... "
sudo snap install microk8s --classic --channel=$RELEASE/stable

echo "Mojaloop: enable helm ... "
microk8s.enable helm3 
echo "Mojaloop: enable dns ... "
microk8s.enable dns
echo "Mojaloop: enable storage ... "
microk8s.enable storage
echo "Mojaloop: enable ingress ... "
microk8s.enable ingress
echo "Mojaloop: install postman ..."   
sudo snap install postman

echo "Mojaloop: add convenient aliases..." 
snap alias microk8s.kubectl kubectl
snap alias microk8s.helm3 helm

echo "Mojaloop: add vagrant user to microk8s group"
usermod -a -G microk8s vagrant
#chown -f -R vagrant ~vagrant/.kube

echo "Mojaloop: add repos and deploy helm charts ..." 
su - vagrant -c "microk8s.helm3 repo add mojaloop http://mojaloop.io/helm/repo/"
su - vagrant -c "microk8s.helm3 repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator"
su - vagrant -c "microk8s.helm3 repo add kiwigrid https://kiwigrid.github.io"
su - vagrant -c "microk8s.helm3 repo add elastic https://helm.elastic.co"
su - vagrant -c "microk8s.helm3 repo update"
su - vagrant -c "microk8s.helm3 list"
su - vagrant -c "microk8s.helm3 repo list"
    
#echo "MojaLoop: Deploy mojaloop" 
# Note troubleshooting guide and the need for updated values.yml
# see https://mojaloop.io/documentation/deployment-guide/deployment-troubleshooting.html#31-ingress-rules-are-not-resolving-for-nginx-ingress-v022-or-later
# TODO : verify that these values.yml updates are needed for the ingress re-write rules and then
#        incorporate this fix here. use helm show values to capture the latest values.yml file
#helm --namespace demo --name moja install mojaloop/mojaloop



