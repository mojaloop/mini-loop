#!/usr/bin/env bash

export PATH=/snap/bin:$PATH
POSTMAN_ENV_FILE=/vagrant/postman/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_DIR=/vagrant/postman

echo "-== Creating Hub Accounts ==-"
newman run --delay-request=2000 --folder='Hub Account' \
--environment=$POSTMAN_ENV_FILE \
$POSTMAN_COLLECTION_DIR/OSS-New-Deployment-FSP-Setup.postman_collection.json

echo "-== Onboarding PayerFSP ==-"
newman run --delay-request=2000 --folder='payeefsp (p2p transfers)' \
--environment=$POSTMAN_ENV_FILE \
$POSTMAN_COLLECTION_DIR/OSS-New-Deployment-FSP-Setup.postman_collection.json

echo "-== Onboarding PayeeFSP ==-"
newman run --delay-request=2000 --folder='payerfsp (p2p transfers)' \
--environment=$POSTMAN_ENV_FILE \
$POSTMAN_COLLECTION_DIR/OSS-New-Deployment-FSP-Setup.postman_collection.json OSS-New-Deployment-FSP-Setup.postman_collection.json
