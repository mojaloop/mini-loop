#!/usr/bin/env bash

##
# Runs a demo transfer
#
##
export CLUSTER_IP="localhost"
export CURRENCY="AUD"
#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#source $DIR/../config/.compiled_env

red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
white=$'\e[0m'


echo 'Setting up environment'

TRANSFER_ID=$(od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
DATE=$(echo 'nowDate = new Date(); console.log(nowDate.toGMTString());' > /tmp/date && node /tmp/date)
EXPIRATION_DATE=$(echo 'nowDate = new Date(); nowDate.setDate(nowDate.getDate() + 1); console.log(nowDate.toISOString());' > /tmp/date && node /tmp/date)
COMPLETED_TIMESTAMP=$(echo 'nowDate = new Date(); nowDate.setDate(nowDate.getDate()); console.log(nowDate.toISOString());' > /tmp/date && node /tmp/date)

PAYEE_FSP_ID="payeefsp"
PAYER_FSP_ID="payerfsp"

createTransfer() {
  echo $cyn"Creating the transfer (request from Payer -> Payee) $white"

  curl --fail -X POST \
    http://${CLUSTER_IP}/transfers \
    -H 'Accept: application/vnd.interoperability.quotes+json;version=1' \
    -H 'Content-Type: application/vnd.interoperability.quotes+json;version=1.0' \
    -H 'Cache-Control: no-cache' \
    -H "Date: $DATE" \
    -H "FSPIOP-Destination: $PAYEE_FSP_ID" \
    -H "FSPIOP-Source: $PAYER_FSP_ID" \
    -H 'Host: ml-api-adapter.local' \
    -d '{
  "transferId": "'$TRANSFER_ID'",
  "payeeFsp": "'$PAYEE_FSP_ID'",
  "payerFsp": "'$PAYER_FSP_ID'",
  "amount": {
    "amount": "100",
    "currency": "'$CURRENCY'"
  },
  "ilpPacket": "AQAAAAAAAABkEGcuZXdwMjEuaWQuODAwMjCCAhd7InRyYW5zYWN0aW9uSWQiOiJmODU0NzdkYi0xMzVkLTRlMDgtYThiNy0xMmIyMmQ4MmMwZDYiLCJxdW90ZUlkIjoiOWU2NGYzMjEtYzMyNC00ZDI0LTg5MmYtYzQ3ZWY0ZThkZTkxIiwicGF5ZWUiOnsicGFydHlJZEluZm8iOnsicGFydHlJZFR5cGUiOiJNU0lTRE4iLCJwYXJ0eUlkZW50aWZpZXIiOiIyNTYxMjM0NTYiLCJmc3BJZCI6IjIxIn19LCJwYXllciI6eyJwYXJ0eUlkSW5mbyI6eyJwYXJ0eUlkVHlwZSI6Ik1TSVNETiIsInBhcnR5SWRlbnRpZmllciI6IjI1NjIwMTAwMDAxIiwiZnNwSWQiOiIyMCJ9LCJwZXJzb25hbEluZm8iOnsiY29tcGxleE5hbWUiOnsiZmlyc3ROYW1lIjoiTWF0cyIsImxhc3ROYW1lIjoiSGFnbWFuIn0sImRhdGVPZkJpcnRoIjoiMTk4My0xMC0yNSJ9fSwiYW1vdW50Ijp7ImFtb3VudCI6IjEwMCIsImN1cnJlbmN5IjoiVVNEIn0sInRyYW5zYWN0aW9uVHlwZSI6eyJzY2VuYXJpbyI6IlRSQU5TRkVSIiwiaW5pdGlhdG9yIjoiUEFZRVIiLCJpbml0aWF0b3JUeXBlIjoiQ09OU1VNRVIifSwibm90ZSI6ImhlaiJ9",
  "condition": "otTwY9oJKLBrWmLI4h0FEw4ksdZtoAkX3qOVAygUlTI",
  "expiration": "'$EXPIRATION_DATE'"
  }'

  if [ $? -eq 0 ]; then
    echo -e $grn"Created a transfer with TRANSFER_ID: $TRANSFER_ID $white\n"
  else
    echo $red"Command failed $white" && exit $?
  fi
}


acceptTransfer() {
  echo $cyn"fulfilling the transfer (request from Payee -> Payer) $white"

  curl --fail -X PUT \
    http://${CLUSTER_IP}/transfers/${TRANSFER_ID} \
    -H 'Accept: application/vnd.interoperability.quotes+json;version=1' \
    -H 'Content-Type: application/vnd.interoperability.quotes+json;version=1' \
    -H 'Cache-Control: no-cache' \
    -H "Date: $DATE" \
    -H "FSPIOP-Destination: $PAYER_FSP_ID" \
    -H "FSPIOP-Source: $PAYEE_FSP_ID" \
    -H 'Host: ml-api-adapter.local' \
    -d '{
    "fulfilment": "uU0nuZNNPgilLlLX2n2r-sSE7-N6U4DukIj3rOLvzek",
    "completedTimestamp": "'$COMPLETED_TIMESTAMP'",
    "transferState": "COMMITTED"
  }'

  if [ $? -eq 0 ]; then
    echo -e $grn"Approved transfer: $TRANSFER_ID $white\n"
  else
    echo $red"Command failed $white" && exit $?
  fi

}


getPositions() {
  echo $cyn"Get Payer Position$white"

  curl --fail -X GET \
    http://${CLUSTER_IP}/participants/payerfsp/positions \
    -H 'Host: central-ledger.local'

  if [ $? -eq 0 ]; then
    echo -e $grn"\nSuccess $white\n"
  else
    echo $red"\nCommand failed $white" && exit $?
  fi


  echo $cyn"Get Payee Position$white"


  curl --fail -X GET \
    http://${CLUSTER_IP}/participants/payeefsp/positions \
    -H 'Host: central-ledger.local'

  if [ $? -eq 0 ]; then
    echo -e $grn"\nSuccess $white\n"
  else
    echo $red"\nCommand failed $white" && exit $?
  fi
}

##
# main
##
createTransfer
acceptTransfer
sleep 5
getPositions
