#!/usr/bin/env bash
# mini-loop-simple-install.sh
#  - this script is an inflexible wrapper around the 2 main mini-loop scripts
#    it must be run with sudo and it calls k8s-install.sh and then mojaloop-install.sh 
#    warning: it will remove all Mojaloop deployments and any Microk8s or k3s installations
#    it assumes recent Ubuntu OS
#                      
# Author Tom Daly 
# Date April 2023


function get_user {
  # set the k8s_user 
  k8s_user=`who am i | cut -d " " -f1`
}

function warn_user {
  echo " **********************  WARNING:  ***********************************"
  echo " This script will remove any existing kubernetes k3s or Microk8s installation."
  printf "\n** Notice and Caution ** \n"
  printf "        mini-loop will deploy mojaloop switch to use for  :-\n"
  printf "            - trial \n"
  printf "            - general testing of Mojaloop and its kubernetes environment\n"
  printf "            - integration work and testing to assist DFSPs integrate with Mojaloop core services \n"
  printf "            - education and demonstration by DFSPs, SIs and more\n"
  printf "            - development (including development of Mojaloop core )\n"
  printf "        To be clear: Mojaloop itself is designed to be robust and secure and can be deployed securely \n"
  printf "        This mini-loop install is not implementing security nor high availablity it is about simplicty and cost savings  \n"
  printf "        please see : https://mojaloop.io/ for more information, resources and online training\n"
  echo "Are you sure you want to continue? [y/N]"
  read response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
}

function remove_existing_kubernetes_installations {
  # set the k8s_user 
  $SCRIPTS_DIR/k8s-install.sh -m delete -k k3s 
}

################################################################################
# Function: showUsage
################################################################################
# Description:		Display usage message
# Arguments:		none
# Return values:	none
function showUsage {
	if [ $# -ne 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: sudo $0 
"
	fi
}

################################################################################
# MAIN
################################################################################
k8s_user=""
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"

get_user
warn_user
remove_existing_kubernetes_installations
# install k3s 
$SCRIPTS_DIR/k8s-install.sh -m install -k k3s -v 1.25
# install Mojaloop with 3ppi
su - $k8s_user -c "$SCRIPTS_DIR/mojaloop-install.sh -m install_ml -o thirdparty -f "



