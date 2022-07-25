#!/usr/bin/env bash

function check_arch {
  ## check architecture Mojaloop deploys on x64 only today arm is coming  
  arch=`uname -p`
  if [[ ! "$arch" == "x86_64" ]]; then 
    printf " ** Error: Mojaloop is only running on x86_64 today and not yet running on ARM cpus \n"
    printf "    please see https://github.com/mojaloop/project/issues/2317 for ARM status \n"
    printf " ** \n"
    if [[ ! -z "${DEVMODE}" ]]; then 
      printf "DEVMODE Flag set ==> this flag is for mini-loop development only ==> continuing \n"
    else
      exit 1
    fi
  fi
}

function set_k8s_distro { 
  # various settings can differ between kubernetes releases and distributions 
  # so we need to figure out what kubernetes distribution is installed and running
  if [[ -f "/snap/bin/microk8s" ]]; then 
    k8s_distro="microk8s"
  elif [[ -f "/usr/local/bin/k3s" ]]; then 
    k8s_distro="k3s"
  else
    printf " ** Error: can't find either microk8s or k3s kubernetes distributions  \n"
    printf "    have you run k8s-install.sh to install one of these ? \n"
    printf " ** \n"
    exit 1      
  fi 
  printf " ==> the installed kubernetes distribution appears to be [%s] \n" "$k8s_distro"
}

function set_timeout { 
  ## Set timeout 
  if [[ ! -z "$TSECS" ]]; then 
    TIMEOUT_SECS=${TSECS}s
  else 
    TIMEOUT_SECS=$DEFAULT_TIMEOUT_SECS 
  fi
  printf " ==> Setting TIMEOUT_SECS to %s \n" "$TIMEOUT_SECS"
} 

function set_and_create_namespace { 
  ## Set and create namespace if necessary 
  if [[ ! -z "$NSPACE" ]]; then 
    NAMESPACE=${NSPACE}
    kubectl create namspace "$NAMESPACE" > /dev/null 2>&1
  else 
    NAMESPACE="default" 
  fi
  printf " ==> Setting NAMESPACE to %s \n" "$NAMESPACE"
}

function set_values_file {
  # currently (June 2022) the k3s nginx ingress and the microk8s nginx ingress versions
  # require different annotations.  the current values file included with mini-loop assumes
  # that microk8s is the default and if the k8s_distro is k3s then it adjusts the nginx 
  # annotions accordingly by using the values file for k3s. 
  # Once Mojaloop is updated to use kubernetes 1.22 and beyond then this 
  # will not be necessary as the values file can and will presumably be modified to work across distribtions 
  # seamlessly

  if [[ $k8s_distro == "k3s" ]]; then 
    # get version and check it is v1.21
    k3s_version=`k3s -v | grep v1.21 | perl -ne 'print  if s/^.*v1.21.*$/v1.21/'`
    if [[ $k3s_version == "v1.21" ]]; then 
      # see the notes on the k3s ingesss install in the k8s-install.sh script
      ML_VALUES_FILE="miniloop_k3s_v121_values.yaml"
    fi 
  fi 
  printf " ==> Using the values file [%s] \n" "$ETC_DIR/$ML_VALUES_FILE"
}

function deploy_mojaloop_helm_chart {
  # uninstall the old chart if it exists
  printf " ==> uninstalling any previous mojaloop deployment "
  helm uninstall ${RELEASE_NAME} --namespace "$NAMESPACE"  >/dev/null 2>&1
  printf "  [ok] \n\n"

  # install the chart
  printf  " ==> install %s helm chart and wait for upto %s  secs for it to be ready \n" "$RELEASE_NAME" "$TIMEOUT_SECS"
  printf  "     executing helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  mojaloop/mojaloop --version $MOJALOOP_VERSION -f $ETC_DIR/$ML_VALUES_FILE \n "
  helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE" \
               mojaloop/mojaloop --version $MOJALOOP_VERSION -f $ETC_DIR/$ML_VALUES_FILE 

  if [[ `helm status $RELEASE_NAME  --namespace "$NAMESPACE" | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
    printf " ==> [%s] deployed sucessfully \n" "$RELEASE_NAME"
  else 
    printf "** Error: %s helm chart deployment failed \n" "$RELEASE_NAME"
    printf "   Possible reasons include : - \n"
    printf "     very slow internet connection /  issues downloading container images (e.g. docker rate limiting) \n"
    printf "     slow machine/vm instance / insufficient memory to start all pods (6GB = min  , 8GB = preferred ) \n"
    printf "**\n\n"

    printf "The current timeout for all pods to be ready is %s \n" "$TIMEOUT_SECS"
    printf "** Possible actions \n"
    printf "   1) allow the deployment to run a little longer , you an check on progress by running kubectl get pods \n"
    printf "      and examining to see if pods are still reaching \"running\" state over the next 10-20 mins \n"
    printf "      If all the pods do reach running state you can then run the helm tests by executing \n"
    printf "      helm -n %s test ml --logs \n" "$NAMESPACE"  

    printf "   2) You can re-run this script with a timeout value longer than the default %s secs \n" "$DEFAULT_TIMEOUT_SECS"
    printf "       use the -t timeout_secs parameter or run %s -h for example(s) \n" "$0"
    printf "**\n\n"
    exit 1
  fi 
}

function check_deployment_health {
  # verify the health of the deployment 
  # curl to http://ml-api-adapter.local/health and http://central-ledger.local/health
  # TODO: what should we suggest if the endpoints are not working and yet the deployment succeeds ? 
  #       ideally this should never happen from the mini-loop install (ideally)
  if [[ `curl -s http://central-ledger.local/health | \
      perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 3 ]] ; then
      printf  " ** Error: central-leger endpoint healthcheck failed ** \n"
      exit 1
  fi
  if [[ `curl -s http://ml-api-adapter.local/health | \
      perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
      printf  " ** Error: ml-api-adapter endpoint healthcheck failed ** \n"
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
	if [ $# -lt 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: $0 -t secs
Example 1 : $0 -t 3000 # use a timeout of 3000 seconds 
Example 2 : $0 -n moja # create namespace moja and deploy mojaloop into the moja namespace 

Options:
-t secs ............ number of seconds (timeout) to wait for pods to all be reach running state
-n namespace ....... the namespace to deploy mojaloop into 
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
MOJALOOP_VERSION="13.1.1" 
RELEASE_NAME="ml"
DEFAULT_TIMEOUT_SECS="2400s"
TIMEOUT_SECS=0
NAMESPACE="default"
k8s_distro=""
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
ETC_DIR="$( cd $(dirname "$0")/../etc ; pwd )"
ML_VALUES_FILE="miniloop_values.yaml"

# Process command line options as required
while getopts "dft:n:hH" OPTION ; do
   case "${OPTION}" in
        t)  TSECS="${OPTARG}"
        ;;
        n)  NSPACE="${OPTARG}"
        ;;
        d)  DEVMODE="true"
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

printf "\n\n****************************************************************************************\n"
printf " Mojaloop.io mini-loop deploying Mojaloop helm chart >>>  start        \n"
printf "****************************************************************************************\n\n"

check_arch
set_k8s_distro
set_timeout
set_and_create_namespace
set_values_file
deploy_mojaloop_helm_chart
check_deployment_health

printf " ==> %s configuration of mojaloop deployed ok and passes endpoint health checks \n" "$RELEASE_NAME"
printf "     to execute the helm tests against this now running deployment please execute :  \n"
printf "     helm -n %s test ml --logs \n" "$NAMESPACE" 
printf "     \nto uninstall mojaloop please execute : \n"
printf "     helm delete -n %s ml\n"  "$NAMESPACE"


printf "\n** Notice and Caution ** \n"
printf "        mini-loop install scripts have now deployed mojaloop switch to use for  :-\n"
printf "            - trial \n"
printf "            - test \n"
printf "            - education and demonstration \n"
printf "        This installation should *NOT* be treated as a *production* deployment as it is designed for simplicity \n"
printf "        To be clear: Mojaloop itself is designed to be robust and secure and can be deployed securely \n"
printf "        This mini-loop install is neither secure nor robust. \n"
printf "        With this caution in mind , welcome to the full function of Mojaloop\n"
printf "        please see : https://mojaloop.io/ for more information, resources and online training\n"

printf "\n****************************************************************************************\n"
printf " Mojaloop.io mini-loop deploying Mojaloop helm chart >>> end       \n"
printf "****************************************************************************************\n\n"