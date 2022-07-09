#!/usr/bin/env bash
# install_local_miniloop.sh
#               - install mojaloop for kubernetes releases >= v1.22
#                 this script will git clone the latest version of mojaloop from the master branch
#                 and then make then make modifications required to run Mojaloop in the latetest kubernetes versions
#                 before running the helm command to deploy mojaloop
# Note:  once the mojaloop helm charts are updated for kubernbetes 1.22 much (but not all) of the mods here will become 
#        un-necessary.  However this approach of automated local mojaloop chart mods and deployment will remain valuable as it gives 
#        testers and deployers a lot of simplicity and flexibility in the future in light of the rapidly evolving kubernetes releases
# Author Tom Daly 
# Date July 2022


function check_arch {
  ## check architecture Mojaloop deploys on x64 only today arm is coming  
  arch=`uname -p`
  if [[ ! "$arch" == "x86_64" ]]; then 
    printf " ** Error: Mojaloop is only running on x86_64 today and not yet running on ARM cpus \n"
    printf "    please see https://github.com/mojaloop/project/issues/2317 for ARM status \n"
    printf " ** \n"
    if [[ ! -z "${devmode}" ]]; then 
      printf "devmode Flag set ==> this flag is for mini-loop development only ==> continuing \n"
    else
      exit 1
    fi
  fi
}

function check_user {
  # ensure that the user is not root
  if [ "$EUID" -eq 0 ]; then 
    printf " ** Error: please run $0 as non root user ** \n"
    exit 1
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
  printf "==> the installed kubernetes distribution appears to be [%s] \n" "$k8s_distro"
}

function set_mojaloop_timeout { 
  ## Set timeout 
  if [[ ! -z "$tsecs" ]]; then 
    TIMEOUT_SECS=${tsecs}s
  else 
    TIMEOUT_SECS=$DEFAULT_TIMEOUT_SECS 
  fi
  printf "==> Setting Mojaloop chart TIMEOUT_SECS to  [ %s ] \n" "$TIMEOUT_SECS"
} 

function set_and_create_namespace { 
  ## Set and create namespace if necessary 
  if [[ ! -z "$nspace" ]]; then 
    NAMESPACE=${nspace}
    kubectl create namspace "$NAMESPACE" > /dev/null 2>&1
  else 
    NAMESPACE="default" 
  fi
  printf "==> Setting NAMESPACE to [ %s ] \n" "$NAMESPACE"
}

# function set_values_file {
#   # currently (June 2022) the k3s nginx ingress and the microk8s nginx ingress versions
#   # require different annotations.  the current values file included with mini-loop assumes
#   # that microk8s is the default and if the k8s_distro is k3s then it adjusts the nginx 
#   # annotions accordingly by using the values file for k3s. 
#   # Once Mojaloop is updated to use kubernetes 1.22 and beyond then this 
#   # will not be necessary as the values file can and will presumably be modified to work across distribtions 
#   # seamlessly

#   if [[ $k8s_distro == "k3s" ]]; then 
#     # get version and check it is >= 1.22
#     k3s_version=`k3s -v | grep v1.21 | perl -ne 'print  if s/^.*v1.21.*$/v1.21/'`
#     if [[ $k3s_version == "v1.21" ]] || [[ $k3s_version == "v1.20" ]]; then 
      
#     fi 
#   fi 
#   printf " ==> Using the values file [%s] \n" "$ETC_DIR/$ML_VALUES_FILE"
# }

function deploy_mojaloop_from_local {
  # uninstall the old chart if it exists
  printf " ==> uninstalling any previous mojaloop deployment "
  helm uninstall ${RELEASE_NAME} --namespace "$NAMESPACE"  >/dev/null 2>&1
  printf "  [ok] \n\n"

  # install the chart
  printf  " ==> install %s helm chart and wait for upto %s  secs for it to be ready \n" "$RELEASE_NAME" "$TIMEOUT_SECS"
  printf  "     executing helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS $HOME/charts/mojaloop  \n "
  helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE" $HOME/charts/mojaloop  

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


function clone_and_modify_helm_charts { 
  printf "==> cloning mojaloop helm charts repo  "
  if [ ! -z "$force" ]; then 
    #printf "==> removing existing helm directory\n"
    rm -rf $HOME/helm > /dev/null 2>&1
  fi 
  if [ ! -d $HOME/helm ]; then 
    git clone https://github.com/mojaloop/helm.git $HOME/helm > /dev/null 2>&1
    # note: this also updates $ETC_DIR/mysql_values.yaml with a new DB password
    $SCRIPTS_DIR/mod_local_miniloop.py -d $HOME/helm -i > /dev/null 2>&1
    NEED_TO_REPACKAGE="true"
  fi
  printf " [ done ] \n"
}

function repackage_charts {
  if [[ "$NEED_TO_REPACKAGE" == "true" ]]; then 
    printf "==> running repackage of the helm charts to incorporate local modifications "
    current_dir=`pwd`
    cd $HOME/helm
    ./package.sh > /dev/null 2>&1
    if [[ $? -eq 0  ]]; then 
      printf " [ ok ] \n"
    else
      printf " [ failed ] \n"
      printf "** please try running $HOME/helm/package.sh manually to determine the problem **  \n" 
      cd $current_dir
      exit 1
    fi   
    cd $current_dir
  fi 
}

function delete_db {
  #  delete any existing deployment and clean up any pv and pvc's that the bitnami mysql chart seems to leave behind
  printf "==> deleting mojaloop database release %s " "$DB_RELEASE_NAME"
  db_exists=`helm ls | grep $DB_RELEASE_NAME | cut -d " " -f1`
  if [ ! -z $db_exists ] && [ "$db_exists" == "$DB_RELEASE_NAME" ]; then 
    helm delete $DB_RELEASE_NAME > /dev/null 2>&1
    sleep 2 
  fi
  pvc_exists=`kubectl get pvc --namespace "$NAMESPACE" 2>/dev/null | grep $DB_RELEASE_NAME` > /dev/null 2>&1
  if [ ! -z "$pvc_exists" ]; then 
    kubectl get pvc --namespace "$NAMESPACE" | cut -d " " -f1 | xargs kubectl delete pvc > /dev/null 2>&1
    kubectl get pv  --namespace "$NAMESPACE" | cut -d " " -f1 | xargs kubectl delete pv > /dev/null 2>&1
  fi 
  # now check it is all clean
  pvc_exists=`kubectl get pvc --namespace "$NAMESPACE" 2>/dev/null | grep $DB_RELEASE_NAME`
  if [ -z "$pvc_exists" ]; then
    #TODO check that the DB is actually gone along with the pv and pvc's 
    printf " [ ok ] \n"
  else
    printf "** Error: the database has not been deleted cleanly  \n" 
    printf "   please try running the delete again or use helm and kubectl to remove manually  \n"
    printf "   ensure no pv or pvc resources remain defore trying to re-install the dabatase ** \n"
    exit 1
  fi
}

function install_db { 
  db_exists=`helm ls | grep $DB_RELEASE_NAME | cut -d " " -f1`
  # if the database is already deployed please get the user to delete it first
  # TODO do the delete automatically if the force flag is set
  if [ ! -z $db_exists ] && [ "$db_exists" == "$DB_RELEASE_NAME" ]; then 
    printf "** Error: the mojaloop database is already installed please delete before re-install \n" 
    printf "   you can use install_local_miniloop.sh -m delete_db to do this cleanly ** \n"
    exit 1
  fi

  # deploy the bitnami mysql database chart
  printf "==> deploying mojaloop database from bitnami helm chart, waiting upto 300s for it to be ready  \n"
  helm install $DB_RELEASE_NAME bitnami/mysql --wait --timeout 300s --namespace "$NAMESPACE" -f $ETC_DIR/mysql_values.yaml > /dev/null 2>&1
  if [[ `helm status $DB_RELEASE_NAME --namespace "$NAMESPACE" | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
    printf "==> [%s] deployed sucessfully \n" "$DB_RELEASE_NAME"
  else 
      printf " ** Error database has *NOT* been deployed \n" 
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
echo  "USAGE: $0 -m <mode> [-t secs] [-n namespace] [-f] [-h] 
Example 1 : $0 -m install_ml -t 3000 # install mojaloop using a timeout of 3000 seconds 
Example 2 : $0 -m install_ml -n moja # create namespace moja and deploy mojaloop into the moja namespace 
Example 3 : $0 -m install_db         # install the mojaloop database only (no mojaloop install)
Example 4 : $0 -m delete_db          # cleanly delete the mojaloop database only (no mojaloop install)
 
Options:
-m mode ............ install_ml|install_db|delete_db 
-t secs ............ number of seconds (timeout) to wait for pods to all be reach running state
-n namespace ....... the namespace to deploy mojaloop into 
-f force ........... force the cloning and updating of the helm charts (will destory existing $HOME/helm)
-h|H ............... display this message
"
	fi
}

################################################################################
# MAIN
################################################################################

##
# Environment Config & global vars 
##
#MOJALOOP_VERSION="13.1.1" 
ML_RELEASE_NAME="ml"
DB_RELEASE_NAME="db"
DEFAULT_TIMEOUT_SECS="2400s"
TIMEOUT_SECS=0
DEFAULT_NAMESPACE="default"
k8s_distro=""
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
ETC_DIR="$( cd $(dirname "$0")/../etc ; pwd )"
NEED_TO_REPACKAGE="false"
#ML_VALUES_FILE="miniloop_values.yaml"

# Process command line options as required
while getopts "dft:n:m:hH" OPTION ; do
   case "${OPTION}" in
        f)  force="true"
        ;; 
        t)  tsecs="${OPTARG}"
        ;;
        n)  nspace="${OPTARG}"
        ;;
        d)  devmode="true"
        ;; 
        m)  mode="${OPTARG}"
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

printf "\n\n**********************************************************************************************\n"
printf " Mojaloop.io mini-loop deploying local Mojaloop helm chart for kubernetes 1.22+ >>>  start        \n"
printf "************************************************************************************************\n\n"
check_arch
check_user
set_and_create_namespace
set_k8s_distro
set_mojaloop_timeout
printf "\n"

if [[ "$mode" == "install_db" ]]; then
  install_db
elif [[ "$mode" == "delete_db" ]]; then
  delete_db
elif [[ "$mode" == "install_ml" ]]; then
  clone_and_modify_helm_charts
  repackage_charts
  install_db
  #set_mojaloop_values_file
  deploy_mojaloop_from_local

fi 

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

printf "\n****************************************************************************************************************\n"
printf " Mojaloop.io mini-loop deploying local Mojaloop helm chart for kubernetes 1.22+ >>>  start       >>> end       \n"
printf "****************************************************************************************************************\n\n"