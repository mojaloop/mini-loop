#!/usr/bin/env bash
# install mojaloop using Lewis Daly's temporary version
# 18th April 2020

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

##
# Environment Config
##
MOJALOOP_WORKING_DIR=/vagrant
MOJALOOP_TMP_WORKING_DIR=/home/vagrant/tmp/helm
MOJALOOP_CHARTS_DIR=${MOJALOOP_WORKING_DIR}/helm
MOJALOOP_REPO_DIR=${MOJALOOP_CHARTS_DIR}/repo
MOJALOOP_CHARTS_BRANCH='fix/219-kubernetes-17-helm2-2'
RELEASE_NAME="mini-loop"
TIMEOUT_SECS="2400s"

rm -rf ${MOJALOOP_TMP_WORKING_DIR}
rm -rf ${MOJALOOP_CHARTS_DIR}
mkdir -p ${MOJALOOP_TMP_WORKING_DIR}
mkdir -p ${MOJALOOP_CHARTS_DIR}

# Clone into tmp dir to get around virtualbox issue
git clone https://github.com/vessels-tech/helm.git ${MOJALOOP_TMP_WORKING_DIR}
cd ${MOJALOOP_TMP_WORKING_DIR} && git checkout -b $MOJALOOP_CHARTS_BRANCH origin/$MOJALOOP_CHARTS_BRANCH || echo ''
# Remove the .git dir, this causes VirtualBox shared folder failures. Unfortunately this means we lose git history in the shared folder
rm -rf ${MOJALOOP_TMP_WORKING_DIR}/.git
cp -R ${MOJALOOP_TMP_WORKING_DIR}/* ${MOJALOOP_CHARTS_DIR}
cd ${MOJALOOP_CHARTS_DIR}


./package.sh
if [[ $? -ne 0 ]] ; then 
  echo "Error: helm packaging failed"
  exit 1
fi

cd ${MOJALOOP_REPO_DIR}
pwd
python3 -m http.server & 

# JIC this is being re-run , delete any previous release
helm delete $RELEASE_NAME > /dev/null 2>&1

# install the chart
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