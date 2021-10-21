#!/usr/bin/env bash
# test application running in multiple versions of kubernetes 
##
# Bash Niceties
##

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
#trap ' echo "\"${last_command}\" command filed with exit code $?."' EXIT

# exit on unset vars
set -u

function install_v14poc_charts {
  printf "\n========================================================================================\n"
  printf "installing mojaloop v14 PoC \n"
  printf "========================================================================================\n"
        printf "==> install backend services <$BACKEND_NAME> helm chart. Wait upto $BE_TIMEOUT_SECS secs for ready state\n "
        start_timer=$(date +%s)
        su - $k8s_user -c "helm upgrade --install --wait --timeout $BE_TIMEOUT_SECS $BACKEND_NAME \
                           $MOJALOOP_WORKING_DIR/dependencies/backend" >> /dev/null 2>&1
        end_timer=$(date +%s)
        elapsed_secs=$(echo "$end_timer - $start_timer" | bc )
        if [[ `helm status $BACKEND_NAME | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
                printf "    helm release <$BACKEND_NAME> deployed sucessfully after <$elapsed_secs> secs \n\n"
        else 
                echo "    Error: $BACKEND_NAME helm chart  deployment failed "
                exit 1
        fi 

        printf "==> install v14 PoC services <$RELEASE_NAME> helm chart. Wait upto $ML_TIMEOUT_SECS secs for ready state\n"
        start_timer=$(date +%s)
        su - $k8s_user -c "helm upgrade --install --wait --timeout $ML_TIMEOUT_SECS $RELEASE_NAME \
                           $MOJALOOP_WORKING_DIR/mojaloop/mojaloop"  >> /dev/null 2>&1      
        end_timer=$(date +%s)
        elapsed_secs=$(echo "$end_timer - $start_timer" | bc )
        if [[ `helm status $RELEASE_NAME | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
                printf "    helm release <$RELEASE_NAME> deployed sucessfully after <$elapsed_secs> secs \n\n "
        else 
                printf "    Error: $RELEASE_NAME helm chart  deployment failed \n"
                exit 1
        fi 
}

function post_install_health_checks {
        printf  "==> checking health endpoints to verify deployment\n" 
        if [[ `curl -s http://admin-api-svc.local/health | \
            perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
                printf "    Error: admin-api-svc endpoint healthcheck failed\n"
                exit 1 
        fi

        if [[ `curl -s http://transfer-api-svc.local/health | \
            perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
                printf "    Error: transfer-api-svc endpoint healthcheck failed\n"
                exit 1 
        fi
        printf " $RELEASE_NAME configuration of mojaloop passes endpoint health checks\n"
}

function set_versions_to_test {
        # if the versions to test not specified -> use the default version.
        if [ -z ${versions+x} ] ; then
                printf " -v flag not specified => defaulting to CURRENT_K8S_versions %s \n" $DEFAULT_VERSION
                versions=$DEFAULT_VERSION
        fi

        # test we get valid k8S versions selected
        if [[ "$versions" == "all" ]]  ; then
                echo "testing k8s versions ${CURRENT_K8S_VERSIONS[*]}"
                versions_list=${CURRENT_CURRENT_K8S_VERSIONS[*]}
        elif [[ " ${CURRENT_K8S_VERSIONS[*]} " =~ "$versions" ]]; then
                printf  " testing k8s version : %s\n" $versions
                versions_list=($versions)
        else 
                printf "Error: invalid or not supported k8s version specified \n"
                printf "please specify a valid k8s version \n\n"
                showUsage
        fi
}

function run_version_tests {
        printf "========================================================================================\n"
        printf "Running Mojaloop Version Tests \n"
        printf "========================================================================================\n"
        for i in ${versions_list[@]}; do
                echo "CURRENT_K8S_VERSIONS{$i}"
                printf "==> Uninstalling any existing k8s installations\n"
                /usr/local/bin/k3s-uninstall.sh > /dev/null 2>&1   
                printf "==> Installing k8s version: %s\n" $i  
                curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="600" \
                                        INSTALL_K3S_CHANNEL=$i \
                                        INSTALL_K3S_EXEC=" --no-deploy traefik " sh  > /dev/null 2>&1

                
                cp /etc/rancher/k3s/k3s.yaml /home/vagrant/k3s.yaml
                chown vagrant /home/vagrant/k3s.yaml
                chmod 600 /home/vagrant/k3s.yaml   
                export KUBECONFIG=/home/vagrant/k3s.yaml  
                sleep 30             
                if [[ `su - $k8s_user -c "kubectl get nodes "` -ne 0 ]] ; then 
                        printf "    Error: k8s server install failed\n"
                fi

                if [[ $i == "v1.22" ]] ; then
                        nginx_version="4.0.6"
                else 
                        nginx_version="3.33.0"     
                fi
                printf "==> installing nginx-ingress version: %s\n" $nginx_version
                su - $k8s_user -c "helm upgrade --install --wait --timeout 300s ingress-nginx \
                                   ingress-nginx/ingress-nginx --version=$nginx_version  " >> /dev/null 2>&1
                #su - $k8s_user -c "kubectl get pods --all-namespaces "
                if [[ `helm status ingress-nginx | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
                        printf "    helm install of ingress-nginx sucessfull after <$elapsed_secs> secs \n\n"
                else 
                        printf "    Error: ingress-nginx helm chart  deployment failed "
                        exit 1
                fi 

                # assuming this is ok so far => now install the v14.0 ML helm charts
                # should check that the repo exists at this point and clone it if not existing.
                install_v14poc_charts
                post_install_health_checks
        done
}

################################################################################
# Function: showUsage
################################################################################
# Description:		Display usage message
# Arguments:		none
# Return values:	none
#
function showUsage {
	if [ $# -ne 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: $0 [ -m mode ] [ -v version(s)] [-u user]  [-h|H]
Example 1 : version-test.sh -m noinstall # helm install charts on current k8s & ingress 
Example 2 : version-test.sh -m install -v all  # tests charts against k8s versions 1.20,1.21 and 1.22

Options:
-m mode ............ install|noinstall (default : noinstall of k8s and nginx )
-v k8s versions .... all|v1.20|v1.21|v1.22 (default :  v1.22)
-u user ............ non root user to run helm and k8s commands (default : vagrant)
-h|H ............... display this message
"
	fi
}

################################################################################
# MAIN
################################################################################

##
# Environment Config
##
SCRIPTNAME=$0
# Program paths
#BASE_DIR=$( cd $(dirname "$0")/../.. ; pwd )
MOJALOOP_WORKING_DIR=/vagrant/charts
BACKEND_NAME="be" 
RELEASE_NAME="ml"
BE_TIMEOUT_SECS="600s"
ML_TIMEOUT_SECS="600s"
export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
DEFAULT_VERSION="v1.22" # default version to test
DEFAULT_K8S_USER="vagrant"

CURRENT_K8S_VERSIONS=("v1.20" "v1.21"  "v1.22")
versions_list=("")
nginx_version=""

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# chown root /etc/rancher/k3s/k3s.yaml
# chmod 600 /etc/rancher/k3s/k3s.yaml


# Check arguments
# if [ $# -lt 1 ] ; then
# 	showUsage
# 	echo "Not enough arguments -m mode must be specified "
# 	exit 1
# fi

# Process command line options as required
while getopts "m:u:v:hH" OPTION ; do
   case "${OPTION}" in
        m)	mode="${OPTARG}"
        ;;
        v)	versions="${OPTARG}"
        ;;
        u)      k8s_user="${OPTARG}"
        ;;
        h|H)	showUsage
                exit 0
        ;;
        *)	echo  "unknown option"
                showUsage
                exit 1
        ;;
    esac
done

printf "\n\n*** Mojaloop Kubernetes Version Testing Tool ***\n\n"

# set the user to run k8s commands
if [ -z ${k8s_user+x} ] ; then
        k8s_user=$DEFAULT_K8S_USER
fi
printf " running kubernetes and helm commands with user : %s\n" $k8s_user

# if the mode not specified -> default to not installing k8s server.
# this allows testing to happen on previously deployed k8s server
if [ -z ${mode+x} ] ; then
        #printf " -m flag not specified \n"
	mode="noinstall"
fi

# if mode = install we install the k3s server and appropriate nginx 
if [[ "$mode" == "install" ]]  ; then
	printf " -m install specified => k8s and nginx version(s) will be installed\n"
        set_versions_to_test
        run_version_tests

elif [[ "$mode" == "noinstall" ]]  ; then
	printf " k8s and nginx ingress will not be installed\n"
        printf " ignoring and/or clearing any setting for -v flag\n "
        versions=$DEFAULT_VERSION
        install_v14poc_charts
        post_install_health_checks
fi