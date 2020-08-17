#!/usr/bin/env bash

PATH_TO_HELM_REPO=""
MOJALOOP_WORKING_DIR=/tmp
MOJALOOP_CHARTS_DIR=${MOJALOOP_WORKING_DIR}/helm
MOJALOOP_REPO_DIR=${MOJALOOP_CHARTS_DIR}/repo
MOJALOOP_CHARTS_BRANCH='fix/219-kubernetes-17-helm2-2'
RELEASE_NAME="mini-loop"
TIMEOUT_SECS="2400s"
# TODO: where to get postman tag from???
POSTMAN_TAG="v10.1.0"
POSTMAN_COLLECTION_DIR=${MOJALOOP_WORKING_DIR}/postman
POSTMAN_ENV_FILE=${POSTMAN_COLLECTION_DIR}/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_NAME=OSS-New-Deployment-FSP-Setup.postman_collection.json
PATH_TO_KUBECTL_CONFIG=/etc/rancher/k3s/k3s.yaml
export KUBECONFIG=${PATH_TO_KUBECTL_CONFIG}


##
# Install k3s
## 
curl -sfL https://get.k3s.io | sh -
# Change file permissions to normal users can call `kubectl ...`
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

##
# Install Helm
##
curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

##
# Install nvm, node and newman
##
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export NVM_DIR="/root/.nvm"
nvm install 12
nvm use 12
npm install -g newman


##
# Set up /etc/hosts hack for easy access
##

echo "add /etc/hosts entries for local access to mojaloop endpoints" 
ENDPOINTSLIST=(127.0.0.1    localhost forensic-logging-sidecar.local central-kms.local central-event-processor.local email-notifier.local central-ledger.local 
central-settlement.local ml-api-adapter.local account-lookup-service.local 
 account-lookup-service-admin.local quoting-service.local moja-simulator.local 
 central-ledger central-settlement ml-api-adapter account-lookup-service 
 account-lookup-service-admin quoting-service simulator host.docker.internal)
export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

# Doesn't seem to work if there isn't already an entry...
# TODO: add back to this script can be idempotent
# sudo perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts

echo "${ENDPOINTS}" >> /etc/hosts

##
# Download and package helm charts and dependencies
# In the future this would be either the charts on this branch, or the published charts
# once we have kubernetes 1.18 support
##
git clone --branch ${MOJALOOP_CHARTS_BRANCH} https://github.com/vessels-tech/helm.git ${MOJALOOP_CHARTS_DIR}
cd ${MOJALOOP_CHARTS_DIR}
./package.sh
cd ${MOJALOOP_REPO_DIR}

helm delete $RELEASE_NAME > /dev/null 2>&1

pyenv global 3.7.0
python3 -m http.server & 

helm repo add mojaloop http://mojaloop.io/helm/repo/
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm repo add kiwigrid https://kiwigrid.github.io
helm repo add elastic https://helm.elastic.co
helm repo update

helm repo list

##
# Install Mojaloop!
# This takes around 8 minutes
##
helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  http://localhost:8000/mojaloop-10.1.0.tgz 

##
# Verify the health of the deployment 
##
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

echo "-Running Postman ${POSTMAN_COLLECTION_NAME} to seed the Mojaloop Environment-"

git clone --branch $POSTMAN_TAG https://github.com/mojaloop/postman.git ${POSTMAN_COLLECTION_DIR}

##
# Set up the test data
##
newman run --delay-request=2000 \
  --environment=$POSTMAN_ENV_FILE \
  --env-var HOST_SIMULATOR_K8S_CLUSTER=http://mini-loop-simulator \
  $POSTMAN_COLLECTION_DIR/$POSTMAN_COLLECTION_NAME


##
# Run the Golden Path
## 
echo "-== Golden_Path.postman_collection tests==-"
function runGPFolder {
  echo "↳ Folder: ${1}"
  newman run --delay-request=2000  \
    --environment=$POSTMAN_ENV_FILE \
    --env-var HOST_SIMULATOR_K8S_CLUSTER=http://mini-loop-simulator \
    --folder="${1}" \
  $POSTMAN_COLLECTION_DIR/Golden_Path.postman_collection.json  
}

runGPFolder "Pre-test-setup"
runGPFolder "p2p_money_transfer"



# TODO:
#  - better configure the postman versions - what's a sensible default?
#  - get the test output, maybe talk to QA team?
# 