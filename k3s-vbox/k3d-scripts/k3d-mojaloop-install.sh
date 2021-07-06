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
 account-lookup-service-admin quoting-service simulator host.docker.internal  
 dev2-sim-bananabank.mojaloop.live dev2-sim-carrotmm.mojaloop.live dev2-sim-duriantech.mojaloop.live dev2-sim-applebank.mojaloop.live dev2-simulator.mojaloop.live  
 ttk.beta.moja-lab.live ttk-backend-1.beta.moja-lab.live eggmm-ttk.beta.moja-lab.live figmm-ttk.beta.moja-lab.live )

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
#su - vagrant -c "helm repo add kong https://charts.konghq.com" 
su - vagrant -c "helm repo update"
su - vagrant -c "helm repo list"

su - vagrant -c "kubectl create namespace ml-app"
# Install the DBs
su - vagrant -c "kubectl apply -f /vagrant/install/td-ss-mysql.yaml"

#todo Can I test DB install in this script or as a setup verification script ? 

# Install the switch
su - vagrant -c "helm upgrade --install --namespace ml-app mojaloop mojaloop/mojaloop -f  /vagrant/install/k3d-values-oss-lab-v2.yaml"

# install-simulators for applebank and bananabank (at a minimum) and the ingress for the simulators 
su - vagrant -c "helm upgrade --install --namespace ml-app simulators mojaloop/mojaloop-simulator -f /vagrant/install/k3d-values-oss-lab-simulators.yaml"

# Install testing toolkit and the ingress for them 
## TODO: I think these values files for the TTK are wrong and can probably just leave out the --values flag and use the default from the 
##       standard values file for the mojaloop package.  I am checking with LD. 
su - vagrant -c "helm upgrade --install --namespace ml-app figmm-ttk mojaloop/ml-testing-toolkit -f /vagrant/ml-oss-sandbox/config/values-ttk-figmm.yaml"
su - vagrant -c "helm upgrade --install --namespace ml-app eggmm-ttk mojaloop/ml-testing-toolkit -f /vagrant/ml-oss-sandbox/config/values-ttk-eggmm.yaml"
su - vagrant -c "kubectl apply -f /vagrant/install/k3d-ingress_ttk.yaml"  

#npx ml-bootstrap@0.3.16 -c $DIR/../docker-local/ml-bootstrap-config.json5
