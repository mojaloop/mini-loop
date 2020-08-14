#!/usr/bin/env bash

# Script playground for Mojaloop on K3s

export PATH=/snap/bin:$PATH


PATH_TO_HELM_REPO=""
MOJALOOP_WORKING_DIR=/vagrant
MOJALOOP_TMP_WORKING_DIR=/home/vagrant/tmp/helm
MOJALOOP_CHARTS_DIR=${MOJALOOP_WORKING_DIR}/helm
MOJALOOP_REPO_DIR=${MOJALOOP_CHARTS_DIR}/repo
MOJALOOP_CHARTS_BRANCH='fix/219-kubernetes-17-helm2-2'
RELEASE_NAME="mini-loop"
TIMEOUT_SECS="2400s"
POSTMAN_TAG="v10.1.0"
POSTMAN_ENV_FILE=/vagrant/postman/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_DIR=/vagrant/postman
POSTMAN_COLLECTION_NAME=OSS-New-Deployment-FSP-Setup.postman_collection.json
PATH_TO_KUBECTL_CONFIG=/etc/rancher/k3s/k3s.yaml

# required so helm knows which kubectl to look for
export KUBECONFIG=${PATH_TO_KUBECTL_CONFIG}

##
# install k3s and helm
##
# TODO: check installed doesn't work...
if [ ! command -v k3s &> /dev/null ]; then
  echo "installing k3s"
  curl -sfL https://get.k3s.io | sh -
  # TODO: wait for node somehow

  # Change file permissions to normal users can call `kubectl ...`
  sudo chmod 644 /etc/rancher/k3s/k3s.yaml
else 
  echo 'k3s already installed'
fi

if [ ! command -v helm &> /dev/null ]; then
  echo "helm could not be found, installing now"
  curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
else
  echo 'helm already installed'
fi

##
# Install newman
##
if [ ! command -v newman &> /dev/null ]; then
  echo "newman could not be found, installing now"
  npm install -g newman
else
  echo 'newman already installed'
fi


##
# Download charts and package
##
# TODO: just install the latest dev version once this pr is merged in: https://github.com/mojaloop/helm/pull/349
mkdir -p ${POSTMAN_COLLECTION_DIR}
mkdir -p ${MOJALOOP_TMP_WORKING_DIR}
mkdir -p ${MOJALOOP_CHARTS_DIR}

if [ ! "$(ls -A ${MOJALOOP_CHARTS_DIR})" ]; then 
  echo "empty ${MOJALOOP_CHARTS_DIR}"
  # Clone into tmp dir to get around virtualbox issue
  git clone https://github.com/vessels-tech/helm.git ${MOJALOOP_TMP_WORKING_DIR}
  cd ${MOJALOOP_TMP_WORKING_DIR} && git checkout -b $MOJALOOP_CHARTS_BRANCH origin/$MOJALOOP_CHARTS_BRANCH || echo ''
  # Remove the .git dir, this causes VirtualBox shared folder failures. Unfortunately this means we lose git history in the shared folder
  rm -rf ${MOJALOOP_TMP_WORKING_DIR}/.git
  cp -R ${MOJALOOP_TMP_WORKING_DIR}/* ${MOJALOOP_CHARTS_DIR}

  ./package.sh
  if [[ $? -ne 0 ]] ; then 
    echo "Error: helm packaging failed"
    exit 1
  fi
else 
  echo "${MOJALOOP_CHARTS_DIR} exists. Not reinstalling charts"
fi

# JIC this is being re-run , delete any previous release
helm delete $RELEASE_NAME > /dev/null 2>&1

cd ${MOJALOOP_REPO_DIR}

py_proc=`ps -eaf | grep -i "python3 -m http.server" | grep -v grep | awk '{print $2}'`
if [[ ! -z "${py_proc}" ]]; then kill $py_proc; fi
python3 -m http.server & 

kubectl get node

##
# Add Helm Repo Dependencies
##
if [ $(helm repo list | wc -l) -lt 4 ]; then
  helm repo add mojaloop http://mojaloop.io/helm/repo/
  helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
  helm repo add kiwigrid https://kiwigrid.github.io
  helm repo add elastic https://helm.elastic.co
  helm repo update
else 
  echo "Helm repos already installed"
fi

helm repo list


##
# Install Mojaloop Charts
##
echo "install $RELEASE_NAME helm chart and wait for upto $TIMEOUT_SECS secs for it to be ready"
helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  http://localhost:8000/mojaloop-10.1.0.tgz 
if [[ `helm status $RELEASE_NAME | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
  echo "$RELEASE_NAME deployed sucessfully "
else 
  echo "Error: $RELEASE_NAME helm chart  deployment failed "
  echo "Possible reasons include : - "
  echo "     very slow internet connection /  issues downloading images"
  echo "     slow machine / insufficient memory to start all pods (6GB min) "
  echo " The current timeout for all pods to be ready is $TIMEOUT_SECS"
  echo " you may consider increasing this by increasing the setting in scripts/mojaloop-install"
  echo " additionally you might finsh the install by hand : login to the vm and continue to wait for the pods to be ready"
  echo "   vagrant ssh "
  echo "   kubectl get pods #if most are in running state maybe wait a little longer "
  echo "   /vagrant/scripts/set-local-env.sh # to load the mojaloop test data." 
  exit 1
fi 

##
# verify the health of the deployment 
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


##
# Seed Mojaloop Environment
##
echo "-Running Postman ${POSTMAN_COLLECTION_NAME} to seed the Mojaloop Environment-"

if [ ! "$(ls -A ${POSTMAN_COLLECTION_DIR})" ]; then 
  echo "empty ${POSTMAN_COLLECTION_DIR}"
  git clone --branch $POSTMAN_TAG https://github.com/mojaloop/postman.git ${POSTMAN_COLLECTION_DIR}
fi

newman run --delay-request=2000 \
  --environment=$POSTMAN_ENV_FILE \
  --env-var HOST_SIMULATOR_K8S_CLUSTER=http://mini-loop-simulator \
  $POSTMAN_COLLECTION_DIR/$POSTMAN_COLLECTION_NAME




# 4. install postman tests based 
# 5. run tests!





