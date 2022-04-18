#!/usr/bin/env bash

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

  exit $exit_status
}

##
# Environment Config
##
MLUSER="ubuntu"
MOJALOOP_WORKING_DIR=/home/mluser
MOJALOOP_VERSION="13.0.2" 
RELEASE_NAME="ml"
TIMEOUT_SECS="2400s"

# uninstall the old chart if it exists
helm uninstall ${RELEASE_NAME} || echo 'non fatal error uninstalling existing chart'

# install the chart
echo "install $RELEASE_NAME helm chart and wait for upto $TIMEOUT_SECS secs for it to be ready"
helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  mojaloop/mojaloop --version $MOJALOOP_VERSION -f $MOJALOOP_WORKING_DIR/miniloop_values.yaml
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
  echo "   $MLUSER ssh "
  echo "   kubectl get pods #if most are in running state maybe wait a little longer "
  echo "   $MOJALOOP_WORKING_DIR/scripts/02_run_ttk.sh # to run the mojaloop testing toolkit." 
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

echo "$RELEASE_NAME configuration of mojaloop deployed ok and passes endpoint health checks"

