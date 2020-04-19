#!/usr/bin/env bash
export PATH=/snap/bin:$PATH
POSTMAN_ENV_FILE=../postman/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_DIR=../postman

echo "-== running Golden_Path.postman_collection  ==-"
newman run --delay-request=2000  \
--environment=$POSTMAN_ENV_FILE \
$POSTMAN_COLLECTION_DIR/Golden_Path.postman_collection.json