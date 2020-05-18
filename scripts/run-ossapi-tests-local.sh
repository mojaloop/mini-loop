#!/usr/bin/env bash
POSTMAN_ENV_FILE=../postman/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_DIR=../postman

echo "-== running OSS-API-Tests.postman_collection  ==-"
newman run --delay-request=2000 --folder='Hub Account' \
--environment=$POSTMAN_ENV_FILE \
$POSTMAN_COLLECTION_DIR/OSS-API-Tests.postman_collection.json