#!/usr/bin/env bash

# Select which version of postman tests to use
#POSTMAN_TAG="v11.0.0"

echo "add /etc/hosts entries for local access to mojaloop endpoints" 
 # Mojaloop Demo
ENDPOINTSLIST=(127.0.0.1   ml-api-adapter.local central-ledger.local account-lookup-service.local account-lookup-service-admin.local 
quoting-service.local central-settlement-service.local transaction-request-service.local central-settlement.local bulk-api-adapter.local 
moja-simulator.local sim-payerfsp.local sim-payeefsp.local sim-testfsp1.local sim-testfsp2.local sim-testfsp3.local sim-testfsp4.local 
mojaloop-simulators.local finance-portal.local operator-settlement.local settlement-management.local testing-toolkit.local 
testing-toolkit-specapi.local ) 
export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
ping  -c 2 account-lookup-service-admin 

export KUBERNETES_RELEASE=1.20
export PATH=$PATH:/snap/bin
echo $PATH

echo "Mojaloop: run update ..."
apt update

echo "Mojaloop: installing snapd ..."
apt install snapd -y

echo "Mojaloop: installing microk8s release $KUBERNETES_RELEASE ... "
sudo snap install microk8s --classic --channel=$KUBERNETES_RELEASE/stable

microk8s.status --wait-ready

echo "Mojaloop: enable helm ... "
microk8s.enable helm3 
echo "Mojaloop: enable dns ... "
microk8s.enable dns
echo "Mojaloop: enable storage ... "
microk8s.enable storage
echo "Mojaloop: enable ingress ... "
microk8s.enable ingress

echo "Mojaloop: add convenient aliases..." 
snap alias microk8s.kubectl kubectl
snap alias microk8s.helm3 helm

echo "Mojaloop: add vagrant user to microk8s group"
usermod -a -G microk8s vagrant
sudo chown -f -R vagrant ~/.kube

echo "Mojaloop: add repos and deploy helm charts ..." 
su - vagrant -c "microk8s.helm3 repo add mojaloop http://mojaloop.io/helm/repo/"
su - vagrant -c "microk8s.helm3 repo add kiwigrid https://kiwigrid.github.io"
su - vagrant -c "microk8s.helm3 repo add elastic https://helm.elastic.co"
su - vagrant -c "helm repo add bitnami https://charts.bitnami.com/bitnami"
su - vagrant -c "microk8s.helm3 repo update"
su - vagrant -c "microk8s.helm3 list"
su - vagrant -c "microk8s.helm3 repo list"

#TODO chamge the ingress port 
#@see https://discuss.kubernetes.io/t/add-on-ingress-default-port-change-options/14428
