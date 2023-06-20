#!/usr/bin/env bash 
# script to test vanilla deploy of Mojaloop from package repo 
# assumes correct version of kubernetes , helm, ingress etc already installed and configured.
# April 2023 
# see install instructions in readme.md at https://github.com/mojaloop/helm and https://github.com/mojaloop/helm/blob/master/thirdparty/README.md

helm repo add stable https://charts.helm.sh/stable
helm repo add incubator https://charts.helm.sh/incubator
helm repo add kiwigrid https://kiwigrid.github.io
helm repo add kokuwa https://kokuwaio.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add mojaloop-charts https://mojaloop.github.io/charts/repo 
helm repo add redpanda-console https://packages.vectorized.io/public/console/helm/charts/
helm repo add mojaloop http://mojaloop.io/helm/repo/

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
  --set ml-ttk-test-val-tp.tests.enabled=true 
   
helm test ml --logs