#!/usr/bin/env bash

# Script playground for Mojaloop on K3s

PATH_TO_HELM_REPO=""
K3S_CONFIG=/etc/rancher/k3s/k3s.yaml

if [ ! command -v k3s &> /dev/null ]; then
  echo "installing k3s"
  curl -sfL https://get.k3s.io | sh -
  # TODO: wait for node somehow

  # Change file permissions to normal users can call `kubectl ...`
  sudo chmod 644 /etc/rancher/k3s/k3s.yaml
else 
  echo 'k3s already installed'
fi

if [ ! command -v helm &> /dev/null ]; then
  echo "helm could not be found, installing now"
  curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
else
  echo 'helm already installed'
fi


kubectl get node

# TODO: 
# 1. spin up a k3s cluster
# 2. package charts
# 3. install charts
# 4. install postman tests based 
# 5. run tests!