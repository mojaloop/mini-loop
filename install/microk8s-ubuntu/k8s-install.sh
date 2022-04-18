#!/usr/bin/env bash
# k8s-install.sh 
# install microk8s , setup helm and all of the infrastructure ready for mojaloop installation


# TODO : add command line params to enable selection of which release etc 
#        maybe even allow configuration of microk8s or k3s later from command line 
#       - check the ububntu release using lsb_release -a 
#       - put this into circle-ci and merge with k8s-versions-test.sh so that no code is duplicated
#       - chamge the ingress port 
#           @see https://discuss.kubernetes.io/t/add-on-ingress-default-port-change-options/14428



# # Configure the installation
# export KUBERNETES_RELEASE=1.20
# export PATH=$PATH:/snap/bin

# # user that will own the mojaloop software installation 
# MLUSER=tdaly
# echo $PATH

## check running as root 

## check user exists and if not create the user (warn that user will be created)

function add_hosts {
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : update hosts file \n"
    printf "========================================================================================\n"
    ENDPOINTSLIST=(127.0.0.1   ml-api-adapter.local central-ledger.local account-lookup-service.local account-lookup-service-admin.local 
    quoting-service.local central-settlement-service.local transaction-request-service.local central-settlement.local bulk-api-adapter.local 
    moja-simulator.local sim-payerfsp.local sim-payeefsp.local sim-testfsp1.local sim-testfsp2.local sim-testfsp3.local sim-testfsp4.local 
    mojaloop-simulators.local finance-portal.local operator-settlement.local settlement-management.local testing-toolkit.local 
    testing-toolkit-specapi.local ) 
    export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

    perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
    # TODO check the ping actually works > suggest cloud network rules if it doesn't
    #      also for cloud VMs might need to use something other than curl e.g. netcat ? 
    ping  -c 2 account-lookup-service-admin 
}

function do_k8s_install {
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : Installing Kubernetes and tools (helm etc) \n"
    printf "========================================================================================\n"
    
    echo "Mojaloop Microk8s Install: run update ..."
    apt update

    echo "Mojaloop Microk8s Install: installing snapd ..."
    apt install snapd -y

    echo "Mojaloop Microk8s Install: installing microk8s release $KUBERNETES_RELEASE ... "
    sudo snap install microk8s --classic --channel=$KUBERNETES_RELEASE/stable

    microk8s.status --wait-ready

    echo "Mojaloop Microk8s Install: enable helm ... "
    microk8s.enable helm3 
    echo "Mojaloop Microk8s Install: enable dns ... "
    microk8s.enable dns
    echo "Mojaloop: enable storage ... "
    microk8s.enable storage
    echo "Mojaloop: enable ingress ... "
    microk8s.enable ingress

    echo "Mojaloop: add convenient aliases..." 
    snap alias microk8s.kubectl kubectl
    snap alias microk8s.helm3 helm

    echo "Mojaloop: add $MLUSER user to microk8s group"
    usermod -a -G microk8s $MLUSER
    sudo chown -f -R $MLUSER ~/.kube

}

function add_helm_repos { 
  ## add the helm repos required to install and run ML and the v14 PoC
        printf "==> add the helm repos required to install and run ML and the v14 PoC\n" 
        su - $k8s_user -c "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx  > /dev/null 2>&1 "
        su - $k8s_user -c "helm repo update > /dev/null 2>&1 "

    echo "Mojaloop: add repos and deploy helm charts ..." 
su - $MLUSER -c "microk8s.helm3 repo add mojaloop http://mojaloop.io/helm/repo/"
su - $MLUSER -c "microk8s.helm3 repo add kiwigrid https://kiwigrid.github.io"
su - $MLUSER -c "microk8s.helm3 repo add elastic https://helm.elastic.co"
su - $MLUSER -c "helm repo add bitnami https://charts.bitnami.com/bitnami"
su - $MLUSER -c "microk8s.helm3 repo update"
su - $MLUSER -c "microk8s.helm3 list"
su - $MLUSER -c "microk8s.helm3 repo list"

}

function verify_user {
# ensure that the user for k8s exists
        if id -u "$k8s_user" >/dev/null; then
                return
        else
                printf "    Error: The user %s does not exist\n" $k8s_user
                exit 1 
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
echo  "USAGE: $0 [-m mode] [-v k8 version] [-u user]
Example 1 : version-test.sh -m install -v 1.20 # install k8s version 1.20

Options:
-m mode ............ install (install is only option right now)
-v k8s version ..... v1.20 (only v1.20 right now )
-u user ............ non root user to run helm and k8s commands and to own mojaloop (default : mojaloop)
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
BASE_DIR=$( cd $(dirname "$0")/../.. ; pwd )
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CHARTS_WORKING_DIR=${CHARTS_WORKING_DIR:-"/vagrant/charts"}
DEFAULT__K8S_VERSION="v1.22" # default version to test
DEFAULT_K8S_USER="vagrant"
HEALTH_ENDPOINTS_LIST=("admin-api-svc" "transfer-api-svc" "account-lookup-service-admin" "account-lookup-service")
CURRENT_K8S_VERSIONS=("v1.20" "v1.21"  "v1.22")

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

Check arguments
if [ $# -lt 1 ] ; then
	showUsage
	echo "Not enough arguments -m mode must be specified "
	exit 1
fi

# Process command line options as required
while getopts "m:v:u:hH" OPTION ; do
   case "${OPTION}" in
        m)	    mode="${OPTARG}"
        ;;
        v)	    version="${OPTARG}"
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

# set the user to run k8s commands
if [ -z ${k8s_user+x} ] ; then
        k8s_user=$DEFAULT_K8S_USER
fi
verify_user 


add_hosts
do_k8s_install
add_helm_repos 

