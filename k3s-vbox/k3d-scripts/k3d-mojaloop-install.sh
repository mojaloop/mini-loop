#!/usr/bin/env bash
# install mojaloop into k3d 
# uses Lewis Daly's ml-oss-sandbox
# @see: github.com:vessels-tech/ml-oss-sandbox

# add the mojaloop endpoints per doc at 
echo "add /etc/hosts entries for local access to mojaloop endpoints" 
ENDPOINTSLIST=(127.0.0.1    localhost forensic-logging-sidecar.local central-kms.local central-event-processor.local email-notifier.local central-ledger.local 
central-settlement.local ml-api-adapter.local account-lookup-service.local 
 account-lookup-service-admin.local quoting-service.local moja-simulator.local 
 central-ledger central-settlement ml-api-adapter account-lookup-service 
 account-lookup-service-admin quoting-service simulator host.docker.internal )
export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
ping  -c 2 account-lookup-service-admin 

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
su - vagrant -c "helm repo list"

su - vagrant -c "kubectl create namespace ml-app"
# Install the DBs
su - vagrant -c "kubectl apply -f /vagrant/ml-oss-sandbox/charts/base/ss_mysql_td.yaml"

# Install the switch
su - vagrant -c "helm upgrade --install --namespace ml-app mojaloop mojaloop/mojaloop -f  /vagrant/ml-oss-sandbox/config/td-values-oss-lab-v2.yaml"

# install-simulators 
su - vagrant -c "helm upgrade --install --namespace ml-app simulators mojaloop/mojaloop-simulator -f /vagrant/ml-oss-sandbox/config/td-values-oss-lab-simulators.yaml"

# Install testing toolkit
su - vagrant -c "helm upgrade --install --namespace ml-app figmm-ttk mojaloop/ml-testing-toolkit -f /vagrant/ml-oss-sandbox/config/values-ttk-figmm.yaml"
su - vagrant -c "helm upgrade --install --namespace ml-app eggmm-ttk mojaloop/ml-testing-toolkit -f /vagrant/ml-oss-sandbox/config/values-ttk-eggmm.yaml"
#npx ml-bootstrap@0.3.16 -c $DIR/../docker-local/ml-bootstrap-config.json5
