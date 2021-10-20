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

function install_v14poc {
  printf "========================================================================================\n"
  printf "installing mojaloop v14 PoC \n"
  printf "\n"
  printf "========================================================================================\n"
  # install the chart
        echo "install backend services <$BACKEND_NAME> helm chart and wait for upto $BE_TIMEOUT_SECS secs for it to be ready"
        start_timer=$(date +%s)
        su - vagrant -c "helm install --wait --timeout $BE_TIMEOUT_SECS $BACKEND_NAME $MOJALOOP_WORKING_DIR/dependencies/backend"
        end_timer=$(date +%s)
        elapsed_secs=$(echo "$end_timer - $start_timer" | bc )
        if [[ `helm status $BACKEND_NAME | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
                echo "helm release <$BACKEND_NAME> deployed sucessfully after <$elapsed_secs> secs "
        else 
                echo "Error: $BACKEND_NAME helm chart  deployment failed "
                exit 1
        fi 

        echo "install v14 PoC services <$RELEASE_NAME> helm chart and wait for upto $ML_TIMEOUT_SECS secs for it to be ready"
        start_timer=$(date +%s)
        su - vagrant -c "helm install --wait --timeout $ML_TIMEOUT_SECS $RELEASE_NAME $MOJALOOP_WORKING_DIR/mojaloop/mojaloop"        
        end_timer=$(date +%s)
        elapsed_secs=$(echo "$end_timer - $start_timer" | bc )
        if [[ `helm status $RELEASE_NAME | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
                echo "helm release <$RELEASE_NAME> deployed sucessfully after <$elapsed_secs> secs "
        else 
                echo "Error: $RELEASE_NAME helm chart  deployment failed "
                exit 1
        fi 
}

function post_install_health_checks {
        echo "check the endpoints to verify deployment" 
        if [[ `curl -s http://admin-api-svc.local/health | \
            perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
                echo "admin-api-svc endpoint healthcheck failed"
                exit 1 
        fi

        if [[ `curl -s http://transfer-api-svc.local/health | \
            perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
                echo "transfer-api-svc endpoint healthcheck failed"
                exit 1 
        fi
        echo "$RELEASE_NAME configuration of mojaloop deployed ok and passes endpoint health checks"
}

function set_versions_to_test {
        # if the versions to test not specified -> use the default list.
        if [ -z ${VERSIONS+x} ] ; then
                printf " -v flag not specified => defaulting to K8S_VERSIONS %s \n", $K8S_VERSIONS
                VERSIONS=$K8S_VERSIONS
        fi

        # test we get valid k8S versions selected
        if [[ "$VERSIONS" == "all" ]]  ; then
                echo "testing k8s versions ${K8S_VERSIONS[*]}"
        elif [[ " ${K8S_VERSIONS[*]} " =~ "$VERSIONS" ]]; then
                echo "ok we have a valid k8s version"
        else 
                printf "Error: invalid k8s version \n"
                printf "please specify a valid k8s version \n\n"
                showUsage
        fi
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
echo  "USAGE: $0 [ -m mode ] [ -v version(s)]  [-h|H]
Example 1 : version-test.sh -m noinstall # helm install charts on current k8s & ingress 
Example 2 : version-test.sh -m install -v all  # tests charts against k8s versions 1.20,1.21 and 1.22

Options:
-m mode ............ install|noinstall (default : noinstall of k8s and nginx )
-v k8s versions .... all|v1.20|v1.21|v1.22 (default :  v1.22)
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
VERSIONS="v1.22" # default version to test


K8S_VERSIONS=("v1.20" "v1.21"  "v1.22")
#K8S_VERSIONS=("v1.22")
nginx_version=""

# chown root /etc/rancher/k3s/k3s.yaml
# chmod 600 /etc/rancher/k3s/k3s.yaml


# Check arguments
# if [ $# -lt 1 ] ; then
# 	showUsage
# 	echo "Not enough arguments -m mode must be specified "
# 	exit 1
# fi

# Process command line options as required
while getopts "m:v:hH" OPTION ; do
   case "${OPTION}" in
        m)	MODE="${OPTARG}"
        ;;
        v)	VERSIONS="${OPTARG}"
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

# if the mode not specified -> default to not installing k8s server.
# this allows testing to happen on previously deployed k8s server
if [ -z ${MODE+x} ] ; then
        #printf " -m flag not specified \n"
	MODE="noinstall"
fi

# if mode = install we install the k3s server and appropriate nginx 
if [[ "$MODE" == "install" ]]  ; then
	printf " -m install specified => k8s and nginx version(s) will be installed\n"
        set_versions_to_test
elif [[ "$MODE" == "noinstall" ]]  ; then
	printf " k8s and nginx ingress will not be installed\n"
        printf " ignoring and/or clearing any setting for -v flag\n "
        VERSIONS=""
        install_v14poc
fi

exit 

echo $K8S_VERSIONS 

for i in ${K8S_VERSIONS[@]}; do
        echo "K8S_VERSIONS{$i}"
        /usr/local/bin/k3s-uninstall.sh 
        #su - vagrant -c "helm delete ingress-nginx "     
        curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                                INSTALL_K3S_CHANNEL=$i \
                                INSTALL_K3S_EXEC=" --no-deploy traefik " sh  
        
        cp /etc/rancher/k3s/k3s.yaml /home/vagrant/k3s.yaml
        chown vagrant /home/vagrant/k3s.yaml
        chmod 600 /home/vagrant/k3s.yaml   
        export KUBECONFIG=/home/vagrant/k3s.yaml  
        sleep 30             
        su - vagrant -c "kubectl get nodes "  
        
        if [[ $i == "v1.22" ]] ; then
                nginx_version="4.0.6"
        else 
                nginx_version="3.33.0"     
        fi
        echo "installing nginx-ingress version : $nginx_version"
        su - vagrant -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx/ingress-nginx --version=$nginx_version  "
        su - vagrant -c "kubectl get pods --all-namespaces "

        # assuming this is ok so far => now install the v14.0 ML helm charts
        # should check that the repo exists at this point and clone it if not existing.
        install_v14poc
        post_install_health_checks


done
