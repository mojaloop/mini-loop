#!/usr/bin/env bash

##
# Runs a demo transfer
#
##
export CLUSTER_IP="localhost"
export CURRENCY="USD"

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
    -H 'Accept: application/vnd.interoperability.transfers+json;version=1' \
    -H 'Content-Type: application/vnd.interoperability.transfers+json;version=1.0' \
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
  "ilpPacket": "AQAAAAAAAADIEHByaXZhdGUucGF5ZWVmc3CCAiB7InRyYW5zYWN0aW9uSWQiOiIyZGY3NzRlMi1mMWRiLTRmZjctYTQ5NS0yZGRkMzdhZjdjMmMiLCJxdW90ZUlkIjoiMDNhNjA1NTAtNmYyZi00NTU2LThlMDQtMDcwM2UzOWI4N2ZmIiwicGF5ZWUiOnsicGFydHlJZEluZm8iOnsicGFydHlJZFR5cGUiOiJNU0lTRE4iLCJwYXJ0eUlkZW50aWZpZXIiOiIyNzcxMzgwMzkxMyIsImZzcElkIjoicGF5ZWVmc3AifSwicGVyc29uYWxJbmZvIjp7ImNvbXBsZXhOYW1lIjp7fX19LCJwYXllciI6eyJwYXJ0eUlkSW5mbyI6eyJwYXJ0eUlkVHlwZSI6Ik1TSVNETiIsInBhcnR5SWRlbnRpZmllciI6IjI3NzEzODAzOTExIiwiZnNwSWQiOiJwYXllcmZzcCJ9LCJwZXJzb25hbEluZm8iOnsiY29tcGxleE5hbWUiOnt9fX0sImFtb3VudCI6eyJjdXJyZW5jeSI6IlVTRCIsImFtb3VudCI6IjIwMCJ9LCJ0cmFuc2FjdGlvblR5cGUiOnsic2NlbmFyaW8iOiJERVBPU0lUIiwic3ViU2NlbmFyaW8iOiJERVBPU0lUIiwiaW5pdGlhdG9yIjoiUEFZRVIiLCJpbml0aWF0b3JUeXBlIjoiQ09OU1VNRVIiLCJyZWZ1bmRJbmZvIjp7fX19",
  "condition": "HOr22-H3AfTDHrSkPjJtVPRdKouuMkDXTR4ejlQa8Ks",
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
    -H 'Accept: application/vnd.interoperability.transfers+json;version=1' \
    -H 'Content-Type: application/vnd.interoperability.transfers+json;version=1.0' \
    -H 'Cache-Control: no-cache' \
    -H "Date: $DATE" \
    -H "FSPIOP-Destination: $PAYER_FSP_ID" \
    -H "FSPIOP-Source: $PAYEE_FSP_ID" \
    -H 'Host: ml-api-adapter.local' \
    -d '{
    "fulfilment": "UNlJ98hZTY_dsw0cAqw4i_UN3v4utt7CZFB4yfLbVFA",
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
