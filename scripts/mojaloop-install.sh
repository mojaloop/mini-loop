#!/usr/bin/env bash
# miniloop-local-install.sh
#               - install mojaloop in a fast and simple as possible manner for demos , test and education 
#                 the install_ml option of this script will git clone the latest version of mojaloop helm charts from the master branch
#                 and then make anmy needed local modifications to these charts to enable Mojaloop to deploy and run 
#                 in the latetest kubernetes versions.  
#                      
# Author Tom Daly 
# Date July 2022
# Updates : Feb-June 2023 for Mojaloop v15  

# 
# TODO : 
# - move the warning about not using mini-loop for real money to the front and get a user acknowledgement and store it 
#  the idea is to ensure that the user acknowledges the warning , yet maintain suitability of use in pipleines. 
# - tidy up logfile contents
# - truncate logfiles to keep under say 500MB
# - fix the prompt and make sure prompt shows git version ??
#  - tidy up the error exit of the script by creating an error_exit function using trap that takes a string (msg) param
#    this way the program exits always through the same point and I can print out stats etc 
#  - Issue: if we deploy with -o and then come and redeploy without -f or -o then thirdparty and bulk will again be deployed 
#           and this might not be intended <=== this needs checking and fixing


timer() {
  start=$1
  stop=$2
  elapsed=$((stop - start))
  echo $elapsed
}
record_memory_use () { 
  # record the memory use desribed by when the memory was measured 
  mem_when=$1
  total_mem=$(free -m | awk 'NR==2{printf "%.2fGB      | %.2fGB    | %.2f%%", $3/1024, $4/1024, $3*100/($3+$4)}')
  memstats_array["$mem_when"]="$total_mem"
}

function check_arch {
  ## check architecture Mojaloop deploys on x64 only today (it is anticipated ARM will work in the near future)
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
    LOGFILE="$logfiles.log"
    ERRFILE="$logfiles.err"
    echo $LOGFILE
    echo $ERRFILE
  fi 
  touch $LOGFILE
  touch $ERRFILE
  printf "start : mini-loop Mojaloop local install utility [%s]\n" "`date`" >> $LOGFILE
  printf "================================================================================\n" >> $LOGFILE
  printf "start : mini-loop Mojaloop local install utility [%s]\n" "`date`" >> $ERRFILE
  printf "================================================================================\n" >> $ERRFILE

  printf "==> logfiles can be found at %s and %s\n" "$LOGFILE" "$ERRFILE"
}

function clone_mojaloop_helm_repo { 
  printf "==> cloning mojaloop helm charts repo  "
  if [ ! -z "$force" ]; then 
    #printf "==> removing existing helm directory\n"
    rm -rf $HOME/helm >> $LOGFILE 2>>$ERRFILE
  fi 
  if [ ! -d $HOME/helm ]; then 
<<<<<<< HEAD:scripts/mojaloop-install.sh
    git clone https://github.com/mojaloop/helm.git --branch $MOJALOOP_BRANCH --single-branch $HOME/helm >> $LOGFILE 2>>$ERRFILE
    NEED_TO_REPACKAGE="true"
=======
    git clone https://github.com/mojaloop/helm.git --branch v14.1.0 --single-branch $HOME/helm >> $LOGFILE 2>>$ERRFILE
>>>>>>> master:install/mini-loop/scripts/miniloop-local-install.sh
    printf " [ done ] \n"
  else 
    printf "\n    ** INFO: helm repo is not cloned as there is an existing $HOME/helm directory\n"
    printf "    to get a fresh clone of the repo , either delete $HOME/helm of use the -f flag **\n"
  fi
}

function configure_optional_modules {
  printf "==> configuring optional Mojaloop functions to install   \n"
  ram_warning="false"
  for mode in $(echo $install_opt | sed "s/,/ /g"); do
    case $mode in
      bulk)
        MOJALOOP_CONFIGURE_FLAGS_STR+="--bulk "
        ram_warning="true"
        ;;
      thirdparty)
        MOJALOOP_CONFIGURE_FLAGS_STR+="--thirdparty "
        ram_warning="true"
        ;;
      *)
          printf " ** Error: specifying -o option   \n"
          printf "    try $0 -h for help \n" 
          exit 1 
        ;;
    esac
  done 
  if [[ "$ram_warning" == "true" ]]; then 
    printf "    ** WARNING: enabling thirdpary and or bulk seems to require considerable additional ram \n"
    printf "    currently it looks like 16GB is ok for either one but > 16GB for both   **\n"
  fi 
}

function modify_local_mojaloop_helm_charts {
  printf "==> configuring the local mojaloop helm charts "
  if [ ! -z ${domain_name+x} ]; then 
    printf "==> setting domain name to <%s> \n " $domain_name >> $LOGFILE 2>>$ERRFILE
    MOJALOOP_CONFIGURE_FLAGS_STR+="--domain_name $domain_name " 
  fi
  printf "     executing $SCRIPTS_DIR/mojaloop_configure.py $MOJALOOP_CONFIGURE_FLAGS_STR  \n" 
  $SCRIPTS_DIR/mojaloop_configure.py $MOJALOOP_CONFIGURE_FLAGS_STR >> $LOGFILE 2>>$ERRFILE
  if [[ $? -ne 0  ]]; then 
      printf " [ failed ] \n"
      exit 1 
  fi 
  # set the repackage scope depending on what gets configured in the values files
  if [[ $MOJALOOP_CONFIGURE_FLAGS_STR == *"--domain_name"* ]]; then
    NEED_TO_REPACKAGE="true"
  else
    # Check if MOJALOOP_CONFIGURE_FLAGS_STR contains "thirdparty" or "bulk"
    if [[ $MOJALOOP_CONFIGURE_FLAGS_STR == *"thirdparty"* || $MOJALOOP_CONFIGURE_FLAGS_STR == *"bulk"* ]]; then
      NEED_TO_REPACKAGE="true"
    fi
  fi
}

function repackage_mojaloop_charts {
  current_dir=`pwd`
  cd $HOME/helm
  if [[ "$NEED_TO_REPACKAGE" == "true" ]]; then 
    tstart=$(date +%s)
    printf "==> running repackage of the all the Mojaloop helm charts to incorporate local configuration "
    status=`./package.sh >> $LOGFILE 2>>$ERRFILE`
    tstop=$(date +%s)
    telapsed=$(timer $tstart $tstop)
    timer_array[repackage_ml]=$telapsed
    if [[ "$status" -eq 0  ]]; then 
      printf " [ ok ] \n"
      NEED_TO_REPACKAGE="false"
    else
      printf " [ failed ] \n"
      printf "** please try running $HOME/helm/package.sh manually to determine the problem **  \n" 
      cd $current_dir
      exit 1
    fi  
  fi 
 
  cd $current_dir
}

function delete_be {
  #  delete any existing deployment and clean up any pv and pvc's that the bitnami mysql chart seems to leave behind
  printf "==> deleting mojaloop backend services in helm release  [%s] " "$BE_RELEASE_NAME"
  be_exists=`helm ls  --namespace $NAMESPACE | grep $BE_RELEASE_NAME | cut -d " " -f1`
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
  #repackage_mojaloop_charts
  be_exists=`helm ls  --namespace $NAMESPACE | grep $BE_RELEASE_NAME | cut -d " " -f1`
  # deploy the mojaloop example backend chart
  printf "==> deploying mojaloop example backend services helm chart , waiting upto 300s for it to be ready  \n"
  tstart=$(date +%s)
  printf "    helm install $BE_RELEASE_NAME --wait --timeout 600s --namespace "$NAMESPACE" $HOME/helm/example-mojaloop-backend\n"
  helm install $BE_RELEASE_NAME --wait --timeout 300s --namespace "$NAMESPACE" $HOME/helm/example-mojaloop-backend >> $LOGFILE 2>>$ERRFILE
  if [[ `helm status $BE_RELEASE_NAME --namespace "$NAMESPACE" | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
    printf "==> [%s] deployed sucessfully \n" "$BE_RELEASE_NAME"
    tstop=$(date +%s)
    telapsed=$(timer $tstart $tstop)
    timer_array[helm_install_be]=$telapsed
  else 
      printf " ** Error backend services, mysql, kafka etc have *NOT* been deployed \n" 
      exit 1 
  fi 
}

function install_mojaloop_from_local {
  delete_mojaloop_helm_chart
  repackage_mojaloop_charts
  # use any existing bakend chart but let user know 
  be_exists=`helm ls  --namespace $NAMESPACE | grep $BE_RELEASE_NAME | cut -d " " -f1`
  if [ ! -z $be_exists ] && [ "$be_exists" == "$BE_RELEASE_NAME" ]; then 
    printf "    skipping install of new backend services as existing backend services are already deployed \n"
  else
    install_be
  fi 
  # install the chart
  printf  "==> deploy Mojaloop %s helm chart and wait for upto %s  secs for it to be ready \n" "$ML_RELEASE_NAME" "$TIMEOUT_SECS"
  printf  "    executing helm install $ML_RELEASE_NAME --wait --timeout $TIMEOUT_SECS $HOME/helm/mojaloop  \n "
  tstart=$(date +%s)
  helm install $ML_RELEASE_NAME --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE" $HOME/helm/mojaloop  >> $LOGFILE 2>>$ERRFILE
  tstop=$(date +%s)
  telapsed=$(timer $tstart $tstop)
  if [[ `helm status $ML_RELEASE_NAME  --namespace "$NAMESPACE" | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
    printf "   helm release [%s] deployed ok  \n" "$ML_RELEASE_NAME"
    timer_array[helm_install_ml]=$telapsed
  else 
    printf "** Error: %s helm chart deployment failed \n" "$ML_RELEASE_NAME"
    printf "   Possible reasons include : - \n"
    printf "     very slow internet connection /  issues downloading container images (e.g. docker rate limiting) \n"
    printf "     slow machine/vm instance / insufficient memory to start all pods \n"
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
  printf "==> check enabled external endpoints are functioning \n" 
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

function print_stats {
  # print out all the elapsed times in the timer_array
  printf "\n********* mini-loop stats *******************************\n"
  printf "kubernetes distro:version  [%s]:[%s] \n" "$k8s_distro" "$k8s_version"

  printf "installation options [%s] \n" "$install_opt"
  pods_num=`kubectl get pods | grep -v "^NAME" | grep Running | wc -l`
  printf "Number of pods running [%s] \n" "$pods_num"
  #helm list --filter $RELEASE_NAME -q | xargs -I {} kubectl get pods -l "app.kubernetes.io/instance={}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
  echo "major processing times :"
  for key in "${!timer_array[@]}"; do
    echo "    $key: ${timer_array[$key]} seconds"
  done
  total_system_mem=$(grep MemTotal /proc/meminfo | awk '{print $2/1024/1024 " GB"}')
  echo 
  echo "Total system memory: $total_system_mem"
  echo "When          | RAM used    | RAM free  | RAM used % "
  echo "-----------------------------------------------------"
  #date=$(date '+%Y-%m-%d %H:%M:%S')
  # Get system memory 
  total_mem=$(free -m | awk 'NR==2{printf "%.2fGB      | %.2fGB    | %.2f%%", $3/1024, $4/1024, $3*100/($3+$4)}')
  #printf "\n%-14s| %s\n" "$date" "$total_mem"

  record_memory_use "at_end"
  for key in "${!memstats_array[@]}"; do
    #echo "$key ${memstats_array[$key]} "
    printf "%-14s| %s\n" "$key" "${memstats_array[$key]}"
  done
  printf "\n************ mini-loop stats ******************************\n"
}


function print_end_banner {
  date=$(date +"%d-%B-%Y %H:%M")
  printf "\n\n********************* [%s] *********************************************\n" "$date"
  printf "            -- mini-loop Mojaloop local install utility -- \n"
  printf "*********************  << END >> ********************************************************\n\n" 
}

function print_success_message { 
  printf "==> Mojaloop branch/version[%s] deployed ok and passes endpoint health checks \n" "$MOJALOOP_BRANCH"
  printf "    to execute the helm tests against this now running deployment please execute :  \n"
  printf "    helm -n %s test ml --logs \n" "$NAMESPACE" 


  printf "\n** Notice and Caution ** \n"
  printf "        mini-loop install scripts have now deployed mojaloop switch to use for  :-\n"
  printf "            - trial \n"
  printf "            - general testing of Mojaloop and its kubernetes environment\n"
  printf "            - integration work and testing to assist DFSPs integrate with Mojaloop core services \n"
  printf "            - education and demonstration by DFSPs, SIs and more\n"
  printf "            - development (including development of Mojaloop core )\n"
  printf "        To be clear: Mojaloop itself is designed to be robust and secure and can be deployed securely \n"
  printf "        This mini-loop install is not implementing security nor high availablity it is about simplicty and cost savings  \n"
  printf "        With this caution in mind , welcome to the full function of Mojaloop running on Kubernetes \n"
  printf "        please see : https://mojaloop.io/ for more information, resources and online training\n"

  print_end_banner 
  
}

################################################################################
# Function: showUsage
################################################################################
# Description:		Display usage message
# Arguments:		none
# Return values:	none
function showUsage {
	if [ $# -lt 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: $0 -m <mode> [-t secs] [-n namespace] [-f] [-h] [-s] [-l] [-o thirdparty,bulk] 
Example 1 : $0 -m install_ml -t 3000 # install mojaloop using a timeout of 3000 seconds 
Example 2 : $0 -m install_ml -n moja # create namespace moja and deploy mojaloop into the moja namespace 
Example 3 : $0 -m install_be         # install the mojaloop backend (be) services, mysql, kafka etc  
Example 4 : $0 -m delete_be          # cleanly delete the mojaloop backend (be) services , mysql, kafka zookeeper etc
Example 5 : $0 -m check_ml           # check the health of the ML endpoints
Example 6 : $0 -m config_ml  -o thirdparty,bulk   # configure optional mojaloop functions thirdparty and or bulk-api

Options:
-m mode ............ install_ml|check_ml|delete_ml|install_be|delete_be
-d domain name ..... domain name for ingress hosts e.g mydomain.com 
-t secs ............ number of seconds (timeout) to wait for pods to all be reach running state
-n namespace ....... the namespace to deploy mojaloop into 
-l logfilename ..... the name of the .log and .err files to create in /tmp
-o module(s) ....... ml functions to toggle on (thirdparty | bulk)  
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
MOJALOOP_BRANCH="v15.0.0"
LOGFILE="/tmp/miniloop-install.log"
ERRFILE="/tmp/miniloop-install.err"
DEFAULT_TIMEOUT_SECS="2400s"
TIMEOUT_SECS=0
DEFAULT_NAMESPACE="default"
k8s_distro=""
k8s_version=""
K8S_CURRENT_RELEASE_LIST=( "1.26" "1.27" )
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
ETC_DIR="$( cd $(dirname "$0")/../etc ; pwd )"
NEED_TO_REPACKAGE="false"
EXTERNAL_ENDPOINTS_LIST=(ml-api-adapter.local central-ledger.local quoting-service.local transaction-request-service.local moja-simulator.local ) 
export MOJALOOP_CONFIGURE_FLAGS_STR=" -d $HOME/helm " 
declare -A timer_array
declare -A memstats_array
record_memory_use "at_start"


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

date=$(date +"%d-%B-%Y %H:%M")
printf "\n\n******************* [%s] **********************************************\n"  "$date"
printf "            -- mini-loop Mojaloop local install utility -- \n"
printf "   utilities for deploying local Mojaloop helm chart(s) for kubernetes   \n"
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

if [[ "$mode" == "install_be" ]]; then
  tstart=$(date +%s)
  clone_mojaloop_helm_repo
  install_be
  tstop=$(date +%s)
  telapsed=$(timer $tstart $tstop)
  timer_array[install_be]=$telapsed
  print_stats
  print_end_banner
elif [[ "$mode" == "delete_be" ]]; then
  delete_be
  print_end_banner
elif [[ "$mode" == "delete_ml" ]]; then
  delete_mojaloop_helm_chart
  print_end_banner
elif [[ "$mode" == "install_ml" ]]; then
  tstart=$(date +%s)
  clone_mojaloop_helm_repo
  configure_optional_modules
  modify_local_mojaloop_helm_charts
  install_mojaloop_from_local
  check_mojaloop_health
  tstop=$(date +%s)
  telapsed=$(timer $tstart $tstop)
  timer_array[install_ml]=$telapsed
  print_stats
  print_success_message 
elif [[ "$mode" == "check_ml" ]]; then
  check_mojaloop_health
  print_end_banner
else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 