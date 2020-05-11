#!/usr/bin/env bash
# install mojaloop using Lewis Daly's temporary version
# 18th April 20202

##
# Bash Niceties
##

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'cleanup && echo "\"${last_command}\" command filed with exit code $?."' EXIT

# exit on errors
set -e

# exit on unset vars
set -u

##
# Cleanup 
## 
function cleanup {
  echo 'Cleaning up'
  # TODO: enable
  mkdir -p ${MOJALOOP_TMP_WORKING_DIR}
  
  # we are finished with the http server, so clean it up by killing it.
  py_proc=`ps -eaf | grep -i "python3 -m http.server" | grep -v grep | awk '{print $2}'`
  if [[ ! -z "${py_proc}" ]]; then kill $py_proc; fi
}

##
# Environment Config
##
MOJALOOP_WORKING_DIR=/vagrant
MOJALOOP_TMP_WORKING_DIR=/home/vagrant/tmp/helm
MOJALOOP_CHARTS_DIR=${MOJALOOP_WORKING_DIR}/helm
MOJALOOP_REPO_DIR=${MOJALOOP_WORKING_DIR}/repo
MOJALOOP_CHARTS_BRANCH='fix/219-kubernetes-17'

rm -rf ${MOJALOOP_TMP_WORKING_DIR}
rm -rf ${MOJALOOP_CHARTS_DIR}
mkdir -p ${MOJALOOP_TMP_WORKING_DIR}
mkdir -p ${MOJALOOP_CHARTS_DIR}

# Clone into tmp dir to get around virtualbox issue
git clone https://github.com/vessels-tech/helm.git ${MOJALOOP_TMP_WORKING_DIR}
cd ${MOJALOOP_TMP_WORKING_DIR} && git checkout -b $MOJALOOP_CHARTS_BRANCH origin/$MOJALOOP_CHARTS_BRANCH || echo ''
# Remove the .git dir, this causes VirtualBox shared folder failures. Unfortunately this means we lose git history in the shared folder
rm -rf ${MOJALOOP_TMP_WORKING_DIR}/.git
cp -R ${MOJALOOP_TMP_WORKING_DIR} ${MOJALOOP_CHARTS_DIR}
cd ${MOJALOOP_CHARTS_DIR}

./package.sh
cd ${MOJALOOP_REPO_DIR}
pwd
python3 -m http.server & 

# TODO: handle uninstall/upgrade path
# helm uninstall moja 
# TODO: helm uninstall any previous charts OR message that user should re-provision VM 
# if mojaloop is already running , in any case check if it is and bail.
helm install moja http://localhost:8000/mojaloop-9.3.0.tgz 

cleanup