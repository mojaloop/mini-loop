#!/usr/bin/env bash
export PATH=/snap/bin:$PATH
POSTMAN_ENV_FILE=/vagrant/postman/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_DIR=/vagrant/postman

echo "-== Golden_Path.postman_collection tests==-"
function runGPFolder {
  echo "↳ Folder: ${1}"
  newman run --delay-request=2000  \
    --environment=$POSTMAN_ENV_FILE \
    --env-var HOST_SIMULATOR_K8S_CLUSTER=http://mini-loop-simulator \
    --folder="${1}" \
  $POSTMAN_COLLECTION_DIR/ML_OSS_Golden_Path_LegacySim.postman_collection.json
}

runGPFolder "Pre-test-setup"
runGPFolder "p2p_money_transfer"