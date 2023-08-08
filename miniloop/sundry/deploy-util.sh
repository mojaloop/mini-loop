#!/usr/bin/env bash
# small util for deploying and undeploying vNext components 

function showUsage {
  echo  "USAGE: $0 [install | uninstall ] "
  exit
}

function install {
    echo "install"

    fspiop-api-svc-data-persistentvolumeclaim.yaml
    

    kubectl apply -f transfers-command-handler-svc-data-persistentvolumeclaim.yaml
    kubectl apply -f transfers-command-handler-svc-deployment.yaml
 
}

function uninstall {
  echo "uninstalling"
  kubectl delete -f transfers-command-handler-svc-deployment.yaml
  kubectl delete -f transfers-command-handler-svc-data-persistentvolumeclaim.yaml
  
}

###################### Main ##########################################

while [[ $# -gt 0 ]] ; do
  if [[ $1 == "install" ]] ; then
    install
  elif [[ $1 == "uninstall" ]] ; then
    uninstall
  elif [[ $1 == "-h" ]] ; then
    showUsage
  else 
    echo "error"
    showUsage
  fi
  shift
done






