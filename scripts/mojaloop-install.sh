#!/usr/bin/env bash
# miniloop-local-install.sh
#               - install mojaloop in a fast and simple as possible manner for demos , test and education 
#                 the install_ml option of this script will git clone the latest version of mojaloop helm charts from the master branch
#                 and then make anmy needed local modifications to these charts to enable Mojaloop to deploy and run 
#                 in the latetest kubernetes versions.  
#                      
# Author Tom Daly 
# Date July 2022
# Updates : Feb 2023 for Mojaloop v15  
#  - updated to pull helm repo version 15 git clone –single-branch –branch command
#   - add in the DNS , FQDN work as options too 
#   - include 3ppi install as option or by default (check the work I have in the branch for this)
#   - fix the prompt and make sure promt shows git version
#   - test bulk
#   - test BizOps framework 
# 
# TODO : 
# - check delete_be : dont delete be is the ML chart exists and is running 

function check_arch {
  ## check architecture Mojaloop deploys on x64 only today arm is coming  
  arch=`uname -p`
  if [[ ! "$arch" == "x86_64" ]]; then 
    printf " ** Error: Mojaloop is only running on x86_64 today and not yet running on ARM cpus \n"
    printf "    please see https://github.com/mojaloop/project/issues/2317 for ARM status \n"
    printf " ** \n"
    exit 1
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

function set_k8s_version { 
  k8s_version=`kubectl version --short 2>/dev/null | grep "^Server" | perl -ne 'print if s/^.*v1.(\d+).*$/v1.\1/'`
}

function print_current_k8s_releases {
    printf "          Current Kubernetes releases are : " 
    for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
        printf " [v%s]" "$i"
    done
    printf "\n"
}

function check_k8s_version_is_current {
  is_current_release=false
  ver=`echo $k8s_version|  tr -d A-Z | tr -d a-z `
  for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
      if  [[ "$ver" == "$i" ]]; then
        is_current_release=true
        break
      fi  
  done
  if [[ ! $is_current_release == true ]]; then 
      printf "** Error: The current installed kubernetes release [ %s ] is not a current release \n" "$k8s_version"
      printf "          you must have a current kubernetes release installed to use this script \n"
      print_current_k8s_releases 
      printf "          for releases of kubernetes earlier than v1.22 mini-loop 3.0 might be of use \n"
      printf "** \n"
      exit 1
  fi 
  printf "==> the installed kubernetes release or version is detected to be  [%s] \n" "$k8s_version"
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
    kubectl create namspace "$NAMESPACE" >> $LOGFILE 2>>$ERRFILE
  else 
    NAMESPACE="default" 
  fi
  printf "==> Setting NAMESPACE to [ %s ] \n" "$NAMESPACE"
}

function set_logfiles {
  # set the logfiles
  if [ ! -z ${logfiles+x} ]; then 
    LOGFILE="/tmp/$logfiles.log"
    ERRFILE="/tmp/$logfiles.err"
    echo $LOGFILE
    echo $ERRFILE
  fi 
  touch $LOGFILE
  touch $ERRFILE
  printf "start : mini-loop Mojaloop local install utility [%s]\n" "`date`" >> $LOGFILE
  printf "================================================================================\n" >> $LOGFILE
  printf "start : mini-loop Mojaloop local install utility [%s]\n" "`date`" >> $ERRFILE
  printf "================================================================================\n" >> $ERRFILE

  printf "==> logfiles can be found at %s and %s\n " "$LOGFILE" "$ERRFILE"
}

function clone_helm_charts_repo { 
  printf "==> cloning mojaloop helm charts repo  "
  if [ ! -z "$force" ]; then 
    #printf "==> removing existing helm directory\n"
    rm -rf $HOME/helm >> $LOGFILE 2>>$ERRFILE
  fi 
  if [ ! -d $HOME/helm ]; then 
    git clone https://github.com/mojaloop/helm.git --branch $MOJALOOP_BRANCH --single-branch $HOME/helm >> $LOGFILE 2>>$ERRFILE
    NEED_TO_REPACKAGE="true"
    printf " [ done ] \n"
  else 
    printf "\n ** INFO: helm repo is not cloned as there is an existing $HOME/helm directory\n"
    printf "      to get a fresh clone of the repo , either delete $HOME/helm of use the -f flag **\n"
  fi
}

function configure_optional_modules {
  printf "==> configuring option Mojaloop functions to install   \n"
  if [ -z ${install_opt+x} ] ; then 
    printf " ** Error: mini-loop requires information about which optional modules to configure when using -m config_ml   \n"
    printf "           example: to configure mojaloop to enable thirdparty charts and bulk-api use:-  \n"
    printf "           $0 -m config_ml -o thirdparty,bulk \n"
    exit 1 
  fi 
  for mode in $(echo $install_opt | sed "s/,/ /g"); do
    case $mode in
      bulk)
        MOJALOOP_CONFIGURE_FLAGS_STR+="--bulk "
        ;;
      thirdparty)
        MOJALOOP_CONFIGURE_FLAGS_STR+="--thirdparty "
        ;;
      *)
          printf " ** Error: specifying -o option   \n"
          printf "    try $0 -h for help \n" 
          exit 1 
        ;;
    esac
  done 
}

function modify_local_helm_charts {
  printf "==> configuring the local mojaloop helm charts "
  if [ ! -z ${domain_name+x} ]; then 
    printf "==> setting domain name to <%s> \n " $domain_name >> $LOGFILE 2>>$ERRFILE
    MOJALOOP_CONFIGURE_FLAGS_STR+="--domain_name $domain_name " 
    #$SCRIPTS_DIR/mod_local_miniloop_v15.py -d $HOME/helm -k $k8s_distro >> $LOGFILE 2>>$ERRFILE
  fi

  printf "     executing $SCRIPTS_DIR/mojaloop_configure.py $MOJALOOP_CONFIGURE_FLAGS_STR  \n" 
  $SCRIPTS_DIR/mojaloop_configure.py $MOJALOOP_CONFIGURE_FLAGS_STR
  if [[ $? -ne 0  ]]; then 
      printf " [ failed ] \n"
      exit 1 
  fi 
  NEED_TO_REPACKAGE="true"
  exit 
}

function repackage_charts {
  if [[ "$NEED_TO_REPACKAGE" == "true" ]]; then 
    printf "==> running repackage of the helm charts to incorporate local modifications "
    current_dir=`pwd`
    cd $HOME/helm
    ./package.sh >> $LOGFILE 2>>$ERRFILE
    if [[ $? -eq 0  ]]; then 
      printf " [ ok ] \n"
      NEED_TO_REPACKAGE="false"
    else
      printf " [ failed ] \n"
      printf "** please try running $HOME/helm/package.sh manually to determine the problem **  \n" 
      cd $current_dir
      exit 1
    fi   
    cd $current_dir
  fi 
}

function delete_be {
  #  delete any existing deployment and clean up any pv and pvc's that the bitnami mysql chart seems to leave behind
  printf "==> deleting mojaloop backend services in helm release  [%s] " "$BE_RELEASE_NAME"
  be_exists=`helm ls  --namespace $NAMESPACE | grep $BE_RELEASE_NAME | cut -d " " -f1`
  helm ls  --namespace $NAMESPACE | grep $BE_RELEASE_NAME | cut -d " " -f1
  if [ ! -z $be_exists ] && [ "$be_exists" == "$BE_RELEASE_NAME" ]; then 
    helm delete $BE_RELEASE_NAME  --namespace $NAMESPACE >> $LOGFILE 2>>$ERRFILE
    sleep 2 
  fi
  pvc_exists=`kubectl get pvc --namespace "$NAMESPACE"  2>>$ERRFILE | grep $BE_RELEASE_NAME` >> $LOGFILE 2>>$ERRFILE
  if [ ! -z "$pvc_exists" ]; then 
    kubectl get pvc --namespace "$NAMESPACE" | cut -d " " -f1 | xargs kubectl delete pvc >> $LOGFILE 2>>$ERRFILE
    kubectl get pv  --namespace "$NAMESPACE" | cut -d " " -f1 | xargs kubectl delete pv >> $LOGFILE 2>>$ERRFILE
  fi 
  # now check it is all clean
  pvc_exists=`kubectl get pvc --namespace "$NAMESPACE" 2>>$ERRFILE | grep $BE_RELEASE_NAME`
  if [ -z "$pvc_exists" ]; then
    #TODO check that the backend pods are actually gone along with the pv and pvc's 
    printf " [ ok ] \n"
  else
    printf "** Error: the backend services such as database kafka etc  may not have been deleted cleanly  \n" 
    printf "   please try running the delete again or use helm and kubectl to remove manually  \n"
    printf "   ensure no pv or pvc resources remain defore trying to re-install ** \n"
    exit 1
  fi
}


function install_be { 
  # delete  db cleanly if it is already deployed => so we can confifdently reinstall cleanly 
  delete_be

  # deploy the mojaloop example backend chart
  printf "==> deploying mojaloop example backend services helm chart , waiting upto 300s for it to be ready  \n"
  printf "helm install $BE_RELEASE_NAME --wait --timeout 300s --namespace "$NAMESPACE" $HOME/helm/example-mojaloop-backend\n"
  helm install $BE_RELEASE_NAME --wait --timeout 300s --namespace "$NAMESPACE" $HOME/helm/example-mojaloop-backend >> $LOGFILE 2>>$ERRFILE
  if [[ `helm status $BE_RELEASE_NAME --namespace "$NAMESPACE" | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
    printf "==> [%s] deployed sucessfully \n" "$BE_RELEASE_NAME"
  else 
      printf " ** Error backend services, mysql, kafka etc have *NOT* been deployed \n" 
  fi 
}

function install_mojaloop_from_local {
  # delete the old chart if it exists
  delete_mojaloop_helm_chart 
  install_be

  # install the chart
  printf  " ==> install %s helm chart and wait for upto %s  secs for it to be ready \n" "$ML_RELEASE_NAME" "$TIMEOUT_SECS"
  printf  "     executing helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS $HOME/helm/mojaloop  \n "
  helm install $ML_RELEASE_NAME --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE" $HOME/helm/mojaloop  

  if [[ `helm status $ML_RELEASE_NAME  --namespace "$NAMESPACE" | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
    printf " ==> [%s] deployed sucessfully \n" "$ML_RELEASE_NAME"
  else 
    printf "** Error: %s helm chart deployment failed \n" "$ML_RELEASE_NAME"
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

function delete_mojaloop_helm_chart {
  printf "==> uninstalling mojaloop: helm delete %s --namespace %s" "$NAMESPACE" "$ML_RELEASE_NAME"
  ml_exists=`helm ls -a --namespace $NAMESPACE | grep $ML_RELEASE_NAME | cut -d " " -f1`
  if [ ! -z $ml_exists ] && [ "$ml_exists" == "$ML_RELEASE_NAME" ]; then 
    helm delete $ML_RELEASE_NAME --namespace $NAMESPACE >> $LOGFILE 2>>$ERRFILE
    if [[ $? -eq 0  ]]; then 
      printf " [ ok ] \n"
    else
      printf "\n** Error: helm delete possibly failed \n" "$ML_RELEASE_NAME"
      printf "   run helm delete %s manually   \n" $ML_RELEASE_NAME
      printf "   also check the pods using kubectl get pods --namespace   \n" $ML_RELEASE_NAME
      exit 1
    fi
  else 
    printf " [ helm release %s not deployed => nothing to delete ] \n" $ML_RELEASE_NAME
  fi
}

function check_mojaloop_health {
  # verify the health of the deployment 
  for i in "${EXTERNAL_ENDPOINTS_LIST[@]}"; do
    #curl -s  http://$i/health
    if [[ `curl -s  http://$i/health | \
      perl -nle '$count++ while /\"status\":\"OK+/g; END {print $count}' ` -lt 1 ]] ; then
      printf  " ** Error: [curl -s http://%s/health] endpoint healthcheck failed ** \n" "$i"
      exit 1
    else 
      printf "    ==> curl -s http://%s/health is ok \n" $i 
    fi
    sleep 2 
  done 
}

function print_end_banner {
  printf "\n\n****************************************************************************************\n"
  printf "            -- mini-loop Mojaloop local install utility -- \n"
  printf "********************* << END >> ********************************************************\n\n"
}

function print_success_message { 
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

  print_end_banner 
  
}

################################################################################
# Function: showUsage
################################################################################
# Description:		Display usage message
# Arguments:		none
# Return values:	none
#
# ./myscript.sh -d bulk             # Calls do_bulk
# ./myscript.sh -d thirdparty       # Calls do_thirdparty
# ./myscript.sh -d bof              # Calls do_bof
# ./myscript.sh -d bulk,thirdparty  # Calls do_bulk and do_thirdparty
# ./myscript.sh -d thirdparty,bof   # Calls do_thirdparty and do_bof
# ./myscript.sh -d bulk,bof         # Calls do_bulk and do_bof
# ./myscript.sh -d bulk,thirdparty,bof 
function showUsage {
	if [ $# -lt 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: $0 -m <mode> [-t secs] [-n namespace] [-f] [-h] [-s] [-l] [-o thirdparty,bulk] 
Example 1 : $0 -m install_ml -t 3000 # install mojaloop using a timeout of 3000 seconds 
Example 2 : $0 -m install_ml -n moja # create namespace moja and deploy mojaloop into the moja namespace 
Example 3 : $0 -m install_be         # install the mojaloop backend (be) services, mysql, kafka etc  
Example 4 : $0 -m delete_be          # cleanly delete the mojaloop backend (be) services , mysql, kafka zookeepert etc
Example 5 : $0 -m check_ml           # check the health of the ML endpoints
Example 6 : $0 -m config_ml  -o thirdparty,bulk   # configure optional mojaloop functions thirdparty and or bulk-api

 
Options:
-m mode ............ install_ml|check_ml|delete_ml|install_be|delete_be
-d domain name ..... domain name for ingress hosts e.g mydomain.com 
-t secs ............ number of seconds (timeout) to wait for pods to all be reach running state
-n namespace ....... the namespace to deploy mojaloop into 
-l logfilename ..... the name of the .log and .err files to create in /tmp
-o module(s) ....... ml functions to toggle on
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
ML_RELEASE_NAME="ml"
BE_RELEASE_NAME="be"
MOJALOOP_BRANCH="feat/#3082-utilise-externalised-secrets-for-user-password-management"
LOGFILE="/tmp/miniloop-install.log"
ERRFILE="/tmp/miniloop-install.err"
DEFAULT_TIMEOUT_SECS="2400s"
TIMEOUT_SECS=0
DEFAULT_NAMESPACE="default"
k8s_distro=""
k8s_version=""
K8S_CURRENT_RELEASE_LIST=( "1.24" "1.25" "1.26" )
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
ETC_DIR="$( cd $(dirname "$0")/../etc ; pwd )"
NEED_TO_REPACKAGE="false"
EXTERNAL_ENDPOINTS_LIST=(ml-api-adapter.local central-ledger.local quoting-service.local transaction-request-service.local moja-simulator.local ) 
export MOJALOOP_CONFIGURE_FLAGS_STR=" -d $HOME/helm " 

# Process command line options as required
while getopts "fd:t:n:m:o:l:hH" OPTION ; do
   case "${OPTION}" in
        f)  force="true"
        ;; 
        t)  tsecs="${OPTARG}"
        ;;
        n)  nspace="${OPTARG}"
        ;;
        d)  domain_name="${OPTARG}"
        ;; 
        m)  mode="${OPTARG}"
        ;;
        l)  logfiles="${OPTARG}"
        ;;
        o)  install_opt="${OPTARG}"
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
printf "            -- mini-loop Mojaloop local install utility -- \n"
printf " utilities for deploying local Mojaloop helm chart for kubernetes 1.22+  \n"
printf "********************* << START  >> *****************************************************\n\n"
check_arch
check_user
set_k8s_version
check_k8s_version_is_current 
set_logfiles 
set_and_create_namespace
set_k8s_distro
set_k8s_version
set_mojaloop_timeout
printf "\n"

# if [[ "$mode" == "install_ml" ]]; then
#   configure_optional_modules
#   modify_local_helm_charts
# fi 
# exit 1

if [[ "$mode" == "install_be" ]]; then
  clone_helm_charts_repo
  # if [ -z ${skip_repackage+x} ]; then 
  #   repackage_charts
  # fi
  install_be
  print_end_banner
elif [[ "$mode" == "delete_be" ]]; then
  delete_be
  print_end_banner
elif [[ "$mode" == "delete_ml" ]]; then
  delete_mojaloop_helm_chart
  print_end_banner
elif [[ "$mode" == "install_ml" ]]; then
  clone_helm_charts_repo
  configure_optional_modules
  modify_local_helm_charts
  #modify_local_helm_charts
  # if [ -z ${skip_repackage+x} ]; then 
  #   repackage_charts
  # fi
  #set_mojaloop_values_file
  install_mojaloop_from_local
  check_mojaloop_health
  print_success_message 
elif [[ "$mode" == "check_ml" ]]; then
  check_mojaloop_health
else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 