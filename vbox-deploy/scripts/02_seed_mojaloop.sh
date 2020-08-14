#!/usr/bin/env bash

export PATH=/snap/bin:$PATH
POSTMAN_ENV_FILE=/vagrant/postman/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_DIR=/vagrant/postman
POSTMAN_COLLECTION_NAME=OSS-New-Deployment-FSP-Setup.postman_collection.json

echo "-Running Postman ${POSTMAN_COLLECTION_NAME} to seed the Mojaloop Environment-"

newman run --delay-request=2000 \
  --environment=$POSTMAN_ENV_FILE \
  --env-var HOST_SIMULATOR_K8S_CLUSTER=http://mini-loop-simulator \
  $POSTMAN_COLLECTION_DIR/$POSTMAN_COLLECTION_NAME
