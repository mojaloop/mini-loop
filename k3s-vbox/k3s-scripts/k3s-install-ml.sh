#!/usr/bin/env bash
# use the Makefile from the ml-oss-lab to install ML 
# @see: https://github.com/vessels-tech/ml-oss-sandbox branch k3s-vbox
# 
##
# Bash Niceties
##

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'cleanup  && echo "\"${last_command}\" command filed with exit code $?."' EXIT

# exit on unset vars
set -u

##
# Cleanup 
## 
function cleanup {
  exit_status=$?
  echo 'Cleaning up'  
  # we are finished with the http server, so clean it up by killing it.
  py_proc=`ps -eaf | grep -i "python3 -m http.server" | grep -v grep | awk '{print $2}'`
  if [[ ! -z "${py_proc}" ]]; then kill $py_proc; fi
  
  exit $exit_status
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi


##
# Environment Config
##
MOJALOOP_WORKING_DIR=/vagrant
RELEASE_NAME="ml"
TIMEOUT_SECS="2400s"
NAMESPACE="ml-app"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

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

#Go get the code from ml-oss-sandbox branch k3s-vbox branch
# for right now this is simply a copy from the local directory which is 
# mounted as specified in the Vagrantfile
# TODO : get rid of that mount and get this directly from the GitHub repo

# uninstall the old chart if it exists
helm uninstall ${RELEASE_NAME} -n ${NAMESPACE} || echo 'non fatal error uninstalling existing chart'

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
su - vagrant -c "kubectl apply -f /vagrant/install/k3d-ss-mysql.yaml"
#todo Can I test DB install in this script or as a setup verification script ? 

# Install the switch
su - vagrant -c "helm upgrade --install --namespace ml-app ml mojaloop/mojaloop -f  /vagrant/install/k3d-values-oss-lab-v2.yaml"

# install-simulators for applebank and bananabank (at a minimum) and the ingress for the simulators 
su - vagrant -c "helm upgrade --install --namespace ml-app simulators mojaloop/mojaloop-simulator -f /vagrant/install/k3d-values-oss-lab-simulators.yaml"

# Install testing toolkit and the ingress for them 
## TODO: I think these values files for the TTK are wrong and can probably just leave out the --values flag and use the default from the 
##       standard values file for the mojaloop package.  I am checking with LD. 
su - vagrant -c "helm upgrade --install --namespace ml-app figmm-ttk mojaloop/ml-testing-toolkit -f /vagrant/install/k3d-values-ttk-figmm.yaml"
su - vagrant -c "helm upgrade --install --namespace ml-app eggmm-ttk mojaloop/ml-testing-toolkit -f /vagrant/install/k3d-values-ttk-eggmm.yaml"
su - vagrant -c "kubectl apply -f /vagrant/install/k3d-ingress_ttk.yaml"  


####### older stuff prior to incorporating Lewis Dalys ml-oss-lab configs #########################
# install the chart
# echo "install $RELEASE_NAME helm chart and wait for upto $TIMEOUT_SECS secs for it to be ready"
# helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  mojaloop/mojaloop
# if [[ `helm status $RELEASE_NAME | grep "^STATUS:" | awk '{ print $2 }' ` == "deployed" ]] ; then 
#   echo "$RELEASE_NAME deployed sucessfully "
# else 
#   echo "Error: $RELEASE_NAME helm chart  deployment failed "
#   echo "Possible reasons include : - "
#   echo "     very slow internet connection /  issues downloading images"
#   echo "     slow machine / insufficient memory to start all pods (6GB min) "
#   echo " The current timeout for all pods to be ready is $TIMEOUT_SECS"
#   echo " you may consider increasing this by increasing the setting in scripts/mojaloop-install"
#   echo " additionally you might finsh the install by hand : login to the vm and continue to wait for the pods to be ready"
#   echo "   vagrant ssh "
#   echo "   kubectl get pods #if most are in running state maybe wait a little longer "
#   echo "   /vagrant/scripts/02_seed_mojaloop.sh # to load the mojaloop test data." 
#   echo "  /vagrant/scripts/03_golden_path.sh # to run the golden path tests "
#   exit 1
# fi 

################## end -- older stuff ###########################################
# verify the health of the deployment 
# curl to http://ml-api-adapter.local/health and http://central-ledger.local/health
if [[ `curl -s http://central-ledger.local/health | \
    perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 3 ]] ; then
    echo "central-leger endpoint healthcheck failed"
    exit 1
fi
if [[ `curl -s http://ml-api-adapter.local/health | \
    perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
    echo "ml-api-adapter endpoint healthcheck failed"
    exit 1 
fi

echo "$RELEASE_NAME configuration of mojaloop deployed ok and passes initial health checks"
#cleanup
