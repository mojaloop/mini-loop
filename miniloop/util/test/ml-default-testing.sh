#!/usr/bin/env bash 
# script to test vanilla deploy of Mojaloop from package repo 
# assumes correct version of kubernetes , helm, ingress etc already installed and configured.
# April 2023 
# see install instructions in readme.md at https://github.com/mojaloop/helm and https://github.com/mojaloop/helm/blob/master/thirdparty/README.md


helm repo update 
helm repo list

helm delete ml
helm delete be 

helm install be --wait --timeout 300s mojaloop/example-mojaloop-backend
helm install ml --wait --timeout 2400s mojaloop/mojaloop \
  --set account-lookup-service.account-lookup-service.config.featureEnableExtendedPartyIdType=true \
  --set account-lookup-service.account-lookup-service-admin.config.featureEnableExtendedPartyIdType=true \
  --set thirdparty.enabled=true \
  --set ml-ttk-test-setup-tp.tests.enabled=true \
  --set ml-ttk-test-val-tp.tests.enabled=true \
  --set 
   
helm test ml --logs




