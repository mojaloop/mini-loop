#!/usr/bin/env bash

##
# Runs a demo transfer
# based on postman p2p_money_transfer/p2p_happy_path SEND QUOTE
##

export CLUSTER_IP="localhost"
export CURRENCY="USD"
TRANSFER_ID=$(od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
DATE=$(echo 'nowDate = new Date(); console.log(nowDate.toGMTString());' > /tmp/date && node /tmp/date)
EXPIRATION_DATE=$(echo 'nowDate = new Date(); nowDate.setDate(nowDate.getDate() + 1); console.log(nowDate.toISOString());' > /tmp/date && node /tmp/date)
COMPLETED_TIMESTAMP=$(echo 'nowDate = new Date(); nowDate.setDate(nowDate.getDate()); console.log(nowDate.toISOString());' > /tmp/date && node /tmp/date)



red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
white=$'\e[0m'


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

registerParty() {
  echo $cyn"Register Party: MSISDN/27713803912 with simulator $white"
  curl --fail -X POST http://${CLUSTER_IP}/payeefsp/parties/MSISDN/27713803912 \
    -H 'Content-Type: application/json' \
    -H 'Host: moja-simulator.local' \
    --data-raw '{
      "party": {
          "partyIdInfo": {
              "partyIdType": "MSISDN",
              "partyIdentifier": "27713803912",
              "fspId": "payeefsp"
          },
          "name": "Siabelo Maroka",
          "personalInfo": {
              "complexName": {
                  "firstName": "Siabelo",
                  "lastName": "Maroka"
              },
              "dateOfBirth": "1973-03-03"
          }
        }
      }'

  echo $cyn"Register Party: MSISDN/27713803912 with ALS $white"
  curl --fail -X POST http://${CLUSTER_IP}/participants/MSISDN/27713803912 \
    -H 'Accept: application/vnd.interoperability.participants+json;version=1.0' \
    -H 'Content-Type: application/vnd.interoperability.participants+json;version=1.0' \
    -H "Date: $DATE" \
    -H 'FSPIOP-Source: payeefsp' \
    -H 'Host: account-lookup-service.local' \
    --data-raw '{
        "fspId": "payeefsp",
        "currency": "USD"
    }'

}

partyLookup() {
  echo $cyn"Perform Party Lookup: MSISDN/27713803912 with ALS $white"
  curl --fail http://${CLUSTER_IP}/parties/MSISDN/27713803912 \
    -H 'Accept: application/vnd.interoperability.parties+json;version=1.0' \
    -H 'Content-Type: application/vnd.interoperability.parties+json;version=1.0' \
    -H "Date: $DATE" \
    -H 'FSPIOP-Source: payeefsp' \
    -H 'Host: account-lookup-service.local'
}

createQuote() {
  echo $cyn"Create the quote $white"
  curl --fail --request POST http://${CLUSTER_IP}/quotes \
  -H 'Accept: application/vnd.interoperability.quotes+json;version=1.0' \
  -H 'Content-Type: application/vnd.interoperability.quotes+json;version=1.0' \
  -H "Date: $DATE" \
  -H 'FSPIOP-Source: payerfsp' \
  -H 'FSPIOP-Destination: payeefsp' \
  -H 'Host: quoting-service.local' \
  --data-raw '{
    "quoteId": "ddaa67b3-5bf8-45c1-bfcf-1e8781177c37",
    "transactionId": "97f3f215-37a0-4755-a17c-c39313aa2f98",
    "payer": {
      "partyIdInfo": {
        "partyIdType": "MSISDN",
        "partyIdentifier": "22556999124",
        "fspId": "payerfsp"
      },
      "personalInfo": {
        "complexName": {
          "firstName": "Mats",
          "lastName": "Hagman"
        },
        "dateOfBirth": "1983-10-25"
      }
    },
    "payee": {
      "partyIdInfo": {
        "partyIdType": "MSISDN",
        "partyIdentifier": "22556999125",
        "fspId": "payeefsp"
      }
    },
    "amountType": "SEND",
    "amount": {
      "amount": "99",
      "currency": "USD"
    },
    "transactionType": {
      "scenario": "TRANSFER",
      "initiator": "PAYER",
      "initiatorType": "CONSUMER"
    },
    "note": "hej"
  }'
}

createTransfer() {
  echo $cyn"Send the transfer with TRANSFER_ID: ${TRANSFER_ID} $white"
  curl --fail --request POST http://localhost/transfers \
    -H 'Accept: application/vnd.interoperability.transfers+json;version=1.0' \
    -H 'Content-Type: application/vnd.interoperability.transfers+json;version=1.0' \
    -H "Date: $DATE" \
    -H 'FSPIOP-Source: payerfsp' \
    -H 'FSPIOP-Destination: payeefsp' \
    -H 'FSPIOP-Signature: {"signature":"iU4GBXSfY8twZMj1zXX1CTe3LDO8Zvgui53icrriBxCUF_wltQmnjgWLWI4ZUEueVeOeTbDPBZazpBWYvBYpl5WJSUoXi14nVlangcsmu2vYkQUPmHtjOW-yb2ng6_aPfwd7oHLWrWzcsjTF-S4dW7GZRPHEbY_qCOhEwmmMOnE1FWF1OLvP0dM0r4y7FlnrZNhmuVIFhk_pMbEC44rtQmMFv4pm4EVGqmIm3eyXz0GkX8q_O1kGBoyIeV_P6RRcZ0nL6YUVMhPFSLJo6CIhL2zPm54Qdl2nVzDFWn_shVyV0Cl5vpcMJxJ--O_Zcbmpv6lxqDdygTC782Ob3CNMvg\",\"protectedHeader\":\"eyJhbGciOiJSUzI1NiIsIkZTUElPUC1VUkkiOiIvdHJhbnNmZXJzIiwiRlNQSU9QLUhUVFAtTWV0aG9kIjoiUE9TVCIsIkZTUElPUC1Tb3VyY2UiOiJPTUwiLCJGU1BJT1AtRGVzdGluYXRpb24iOiJNVE5Nb2JpbGVNb25leSIsIkRhdGUiOiIifQ"}' \
    -H 'Host: ml-api-adapter.local'\
    --data-raw '{
      "transferId": "'$TRANSFER_ID'",
      "payerFsp": "payerfsp",
      "payeeFsp": "payeefsp",
      "amount": {
        "amount": "99",
        "currency": "USD"
      },
      "expiration": "'$EXPIRATION_DATE'",
      "ilpPacket": "AQAAAAAAAADIEHByaXZhdGUucGF5ZWVmc3CCAiB7InRyYW5zYWN0aW9uSWQiOiIyZGY3NzRlMi1mMWRiLTRmZjctYTQ5NS0yZGRkMzdhZjdjMmMiLCJxdW90ZUlkIjoiMDNhNjA1NTAtNmYyZi00NTU2LThlMDQtMDcwM2UzOWI4N2ZmIiwicGF5ZWUiOnsicGFydHlJZEluZm8iOnsicGFydHlJZFR5cGUiOiJNU0lTRE4iLCJwYXJ0eUlkZW50aWZpZXIiOiIyNzcxMzgwMzkxMyIsImZzcElkIjoicGF5ZWVmc3AifSwicGVyc29uYWxJbmZvIjp7ImNvbXBsZXhOYW1lIjp7fX19LCJwYXllciI6eyJwYXJ0eUlkSW5mbyI6eyJwYXJ0eUlkVHlwZSI6Ik1TSVNETiIsInBhcnR5SWRlbnRpZmllciI6IjI3NzEzODAzOTExIiwiZnNwSWQiOiJwYXllcmZzcCJ9LCJwZXJzb25hbEluZm8iOnsiY29tcGxleE5hbWUiOnt9fX0sImFtb3VudCI6eyJjdXJyZW5jeSI6IlVTRCIsImFtb3VudCI6IjIwMCJ9LCJ0cmFuc2FjdGlvblR5cGUiOnsic2NlbmFyaW8iOiJERVBPU0lUIiwic3ViU2NlbmFyaW8iOiJERVBPU0lUIiwiaW5pdGlhdG9yIjoiUEFZRVIiLCJpbml0aWF0b3JUeXBlIjoiQ09OU1VNRVIiLCJyZWZ1bmRJbmZvIjp7fX19",
      "condition": "HOr22-H3AfTDHrSkPjJtVPRdKouuMkDXTR4ejlQa8Ks"
    }'
}

checkCallbacks() {
  # TODO: check simulator callbacks
  echo $cyn"Check the PayerFSP simulator callbacks $white"
  curl http://localhost/payerfsp/callbacks/${TRANSFER_ID} \
    -H 'Content-Type: application/json' \
    -H 'Host: moja-simulator.local'
}


##
# main
##
# getPositions
# registerParty
# sleep 3
# partyLookup
# sleep 3
# createQuote
# sleep 3
createTransfer
sleep 3
checkCallbacks