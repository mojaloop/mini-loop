#!/usr/bin/env bash

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
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
ETC_DIR="$( cd $(dirname "$0")/../etc ; pwd )"

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

## Set timeout 
if [[ ! -z "$TSECS" ]]; then 
  TIMEOUT_SECS=${TSECS}s
else 
  TIMEOUT_SECS=$DEFAULT_TIMEOUT_SECS 
fi
printf " ==> Setting TIMEOUT_SECS to %s \n" "$TIMEOUT_SECS"

## Set and create namespace if necessary 
if [[ ! -z "$NSPACE" ]]; then 
  NAMESPACE=${NSPACE}
  kubectl create namspace "$NAMESPACE" > /dev/null 2>&1
else 
  NAMESPACE="default" 
fi
printf " ==> Setting NAMESPACE to %s \n" "$NAMESPACE"

# uninstall the old chart if it exists
printf " ==> uninstalling any previous mojaloop deployment "
helm uninstall ${RELEASE_NAME} --namespace "$NAMESPACE"  >/dev/null 2>&1
printf "  [ok] \n\n"

# install the chart
printf  " ==> install %s helm chart and wait for upto %s  secs for it to be ready \n" "$RELEASE_NAME" "$TIMEOUT_SECS"
#printf  "     executing helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  mojaloop/mojaloop --version $MOJALOOP_VERSION -f $ETC_DIR/miniloop_values.yaml \n "
helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE"  mojaloop/mojaloop --version $MOJALOOP_VERSION -f $ETC_DIR/miniloop_values.yaml 
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

printf " ==> %s configuration of mojaloop deployed ok and passes endpoint health checks \n" "$RELEASE_NAME"
printf "     to execute the helm tests against this now running deployment please execute :  \n"
printf "     helm -n %s test ml --logs \n" "$NAMESPACE" 

