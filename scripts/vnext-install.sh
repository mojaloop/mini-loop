#!/usr/bin/env bash
# vnext-install.sh
#    - install mojaloop vnext version in a light-weight , simple and quick fashion 
#      for demo's testing and development 
#
# refer : @#see @https://github.com/mojaloop/platform-shared-tools            
# Author Tom Daly 
# Date May 2023

handle_error() {
  local exit_code=$?
  local line_number=$1
  local message="$2"
  local script_name="${0##*/}"
  echo
  echo "    ** Error exit code $exit_code on line $line_number : $message Exiting..."
  exit $exit_code
}

function check_arch {
  ## check architecture Mojaloop deploys on x64 only today arm is coming  
  arch=`uname -p`
  if [[ ! "$arch" == "x86_64" ]]; then 
    printf " ** Error: Mojaloop is only running on x86_64 today and not yet running on ARM cpus \n"
    printf "    please see https://github.com/mojaloop/project/issues/2317 for ARM status \n"
    printf " ** \n"
  fi
}

function check_user {
  # ensure that the user is not root
  if [ "$EUID" -eq 0 ]; then 
    printf " ** Error: please run $0 as non root user ** \n"
    exit 1
  fi
}

function check_deployment_dir_exists  {
  if [[ ! -d "$DEPLOYMENT_DIR" ]] &&  [[ "$mode" == "delete_ml" ]]; then
    printf "  ** Error: can't delete as the vNext code is missing  \n"
    printf "            suggest you run again with %s -m install_ml \n" $0
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
  printf "==> the installed kubernetes distribution is  [%s] \n" "$k8s_distro"
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
  printf "==> logfiles can be found at %s and %s \n" "$LOGFILE" "$ERRFILE"
}

function configure_extra_options {
  printf "==> configuring which Mojaloop vNext options to install   \n"
  printf "    ** INFO: no extra options implemented or required for mini-loop vNext at this time ** \n"
  # for mode in $(echo $install_opt | sed "s/,/ /g"); do
  #   case $mode in
  #     logging)
  #       MOJALOOP_CONFIGURE_FLAGS_STR+="--logging "
  #       ram_warning="true"
  #       ;;
  #     *)
  #         printf " ** Error: specifying -o option   \n"
  #         printf "    try $0 -h for help \n" 
  #         exit 1 
  #       ;;
  #   esac
  # done 
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

function clone_mojaloop_repo { 
  #force=$1 
  printf "==> cloning mojaloop vNext branch [%s] to directory [%s]  " $MOJALOOP_BRANCH $REPO_BASE_DIR
  if [[ "$force" == "true" ]]; then
    rm -rf  "$REPO_BASE_DIR" >> $LOGFILE 2>>$ERRFILE
  fi 
  if [ ! -d "$REPO_BASE_DIR" ]; then 
    mkdir "$REPO_BASE_DIR"
    git clone --branch $MOJALOOP_BRANCH https://github.com/mojaloop/platform-shared-tools.git $REPO_DIR > /dev/null 2>&1
    NEED_TO_REPACKAGE="true"
    printf " [ done ] \n"
  else 
    printf "\n    ** INFO: vnext  repo is not cloned as there is an existing $REPO_DIR directory\n"
    printf "    to get a fresh clone of the repo , either delete $REPO_DIR of use the -f flag **\n"
  fi
}

function modify_local_mojaloop_yaml_and_charts {
  printf "==> configuring Mojaloop vNext yaml and helm chart values \n" 
  if [ ! -z ${domain_name+x} ]; then 
    printf "==> setting domain name to <%s> \n " $domain_name 
    MOJALOOP_CONFIGURE_FLAGS_STR+="--domain_name $domain_name " 
  fi

  # TODO We want to avoid running the helm repackage when we don't need to 
  printf "     executing $SCRIPTS_DIR/vnext_configure.py $MOJALOOP_CONFIGURE_FLAGS_STR  \n" 
  $SCRIPTS_DIR/vnext_configure.py $MOJALOOP_CONFIGURE_FLAGS_STR 
  if [[ $? -ne 0  ]]; then 
      printf " [ failed ] \n"
      exit 1 
  fi 
}

function repackage_infra_helm_chart {
  current_dir=`pwd`
  cd $INFRA_DIR
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
      printf "** please try running $INFRA_DIR/package.sh manually to determine the problem **  \n" 
      cd $current_dir
      exit 1
    fi  
  fi 
  cd $current_dir
}

function delete_mojaloop_infra_release {
  printf "==> uninstalling Mojaloop (vNext) infrastructure svcs and deleting resources\n" 
  #helm delete %s --namespace %s" "$NAMESPACE" "$HELM_INFRA_RELEASE"
  ml_exists=`helm ls -a --namespace $NAMESPACE | grep $HELM_INFRA_RELEASE | awk '{print $1}' `
  if [ ! -z $ml_exists ] && [ "$ml_exists" == "$HELM_INFRA_RELEASE" ]; then 
    helm delete $HELM_INFRA_RELEASE --namespace $NAMESPACE >> $LOGFILE 2>>$ERRFILE
    sleep 2
  else 
    printf "\n    [ infrastructure services release %s not deployed => nothing to delete ]   " $HELM_INFRA_RELEASE
  fi
  # now check helm infra release is gone 
  ml_exists=`helm ls -a --namespace $NAMESPACE | grep $HELM_INFRA_RELEASE | awk '{print $1}' `
  if [ ! -z $ml_exists ] && [ "$ml_exists" == "$HELM_INFRA_RELEASE" ]; then 
      printf "\n** Error: helm delete possibly failed \n" "$HELM_INFRA_RELEASE"
      printf "   run helm delete %s manually   \n" $HELM_INFRA_RELEASE
      printf "   also check the pods using kubectl get pods --namespace   \n" $HELM_INFRA_RELEASE
      exit 1
  fi
  # now check that the persistent volumes got cleaned up
  pvc_exists=`kubectl get pvc --namespace "$NAMESPACE"  2>>$ERRFILE | grep $HELM_INFRA_RELEASE` >> $LOGFILE 2>>$ERRFILE
  if [ ! -z "$pvc_exists" ]; then 
    kubectl get pvc --namespace "$NAMESPACE" | cut -d " " -f1 | xargs kubectl delete pvc >> $LOGFILE 2>>$ERRFILE
    kubectl get pv  --namespace "$NAMESPACE" | cut -d " " -f1 | xargs kubectl delete pv >> $LOGFILE 2>>$ERRFILE
  fi 
  # and chexk the pvc and pv are gone 
  pvc_exists=`kubectl get pvc --namespace "$NAMESPACE" 2>>$ERRFILE | grep $HELM_INFRA_RELEASE 2>>$ERRFILE`
  if [ ! -z "$pvc_exists" ]; then
    printf "** Error: the backend persistent volume resources may not have deleted properly  \n" 
    printf "   please try running the delete again or use helm and kubectl to remove manually  \n"
    printf "   ensure no pv or pvc resources remain defore trying to re-install ** \n"
    exit 1
  fi
  # if we get to here then we are reasonably confident infrastructure resources are cleanly deleted
  printf " [ ok ] \n"
}




function install_infra_from_local_chart  {
  printf "start : mini-loop Mojaloop vNext install infrastructure services [%s]\n" "`date`" 
  delete_mojaloop_infra_release
  repackage_infra_helm_chart
  # install the chart
  printf  "==> deploy Mojaloop vNext infrastructure via %s helm chart and wait for upto %s  secs for it to be ready \n" "$ML_RELEASE_NAME" "$TIMEOUT_SECS"
  printf  "    executing helm install $HELM_INFRA_RELEASE --wait --timeout $TIMEOUT_SECS $INFRA_DIR/infra-helm  \n "
  tstart=$(date +%s)
  helm install $HELM_INFRA_RELEASE --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE" $INFRA_DIR/infra-helm  >> $LOGFILE 2>>$ERRFILE
  tstop=$(date +%s)
  telapsed=$(timer $tstart $tstop)
  if [[ `helm status $HELM_INFRA_RELEASE  --namespace "$NAMESPACE" | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
    printf "   helm release [%s] deployed ok  \n" "$HELM_INFRA_RELEASE"
    timer_array[install_infra]=$telapsed
  else 
    printf "** Error: %s helm chart deployment failed \n" "$HELM_INFRA_RELEASE"
    printf "   Possible reasons include : - \n"
    printf "     very slow internet connection /  issues downloading container images (e.g. docker rate limiting) \n"
    printf "     slow machine/vm instance / insufficient memory to start all pods  \n"
    printf "**\n\n"

    printf "The current timeout for all pods to be ready is %s \n" "$TIMEOUT_SECS"
    printf "** Possible actions \n"
    printf "   1) allow the deployment to run a little longer , you an check on progress by running kubectl get pods \n"
    printf "      and examining to see if pods are still reaching \"running\" state over the next 10-20 mins \n"

    printf "   2) You can re-run this script with a timeout value longer than the default %s secs \n" "$DEFAULT_TIMEOUT_SECS"
    printf "       use the -t timeout_secs parameter or run %s -h for example(s) \n" "$0"
    printf "**\n\n"
    exit 1
  fi 
} 

function check_pods_are_running() { 
  local app_layer="$1"
  local wait_secs=90
  local seconds=0 
  local end_time=$((seconds + $wait_secs )) 
  iterations=0
  steady_count=3
  printf "    waiting for all pods in [%s] layer to come to running state ... " $app_layer
  while [ $seconds -lt $end_time ]; do
      local pods_not_running=$(kubectl get pods --selector="mojaloop.layer=$app_layer" | grep -v NAME | grep -v Running | wc -l)
      local containers_not_ready=$(kubectl get pods --selector="mojaloop.layer=$app_layer" --no-headers | awk '{split($2,a,"/"); if (a[1]!=a[2]) print}' | wc -l)

      if [ "$pods_not_running" -eq 0 ] && [ "$containers_not_ready" -eq 0 ]; then
        iterations=$((iterations+1))
        #echo "iterations are $iterations" 
        if [[ $iterations -ge $steady_count ]]; then # ensure pods are running and are stable 
          #printf "    All pods and containers in mojaloop layer [%s] are in running and ready state\n" "$app_layer"
          printf " [ ok ] \n"
          return 0
        fi 
      else 
        iterations=0
      fi 
      sleep 5 
      ((seconds+=5))
  done
  printf "    ** WARNING: Not all pods in application layer=%s are in running state within timeout of %s secs \n" "$app_layer" $wait_secs
} 

check_pods_status() {
  local layer_value="$1"
  local selector="mojaloop.layer=$layer_value"
  local wait_secs=30
  local seconds=0 
  local end_time=$((seconds + $wait_secs )) 

  while [ $seconds -lt $end_time ]; do
    local pods_not_terminating=$(kubectl get pods --selector="$selector" --no-headers | awk '{if ($3!="Terminating") print $1}') > /dev/null 2>&1
    if [ -z "$pods_not_terminating" ]; then
      #echo "All pods with mojaloop.layer=$layer_value are terminating or already gone."
      return 0
    fi
    sleep 5  # Wait for 5 seconds before the next check
    ((seconds+=5))
  done

  printf  "    \n** Warning: Not all pods in application layer [ %s ] are terminating or gone\n" $app_layer
  return 1
}

function delete_mojaloop_layer() { 
  local app_layer="$1"
  local layer_yaml_dir="$2"
  if [[ "$mode" == "delete_ml" ]]; then
    printf "==> delete components in the mojaloop [ %s ] application layer " $app_layer
  else 
    printf "    delete components in the mojaloop [ %s ] application layer " $app_layer
  fi 
  current_dir=`pwd`
  cd $layer_yaml_dir
  yaml_non_dataresource_files=$(ls *.yaml | grep -v '^docker-' | grep -v "\-data\-" )
  yaml_dataresource_files=$(ls *.yaml | grep -v '^docker-' | grep -i "\-data\-" )
  for file in $yaml_non_dataresource_files; do
      kubectl delete -f $file > /dev/null 2>&1 
  done
  for file in $yaml_dataresource_files; do
      kubectl delete -f $file > /dev/null 2>&1 
  done
  cd $current_dir
  check_pods_status $app_layer > /dev/null 2>&1 
  if [[ $? -eq 0  ]]; then 
    printf " [ ok ] \n"
  fi 
}

function install_mojaloop_layer() { 
  local app_layer="$1"
  local layer_yaml_dir="$2"
  printf "==> installing components in the mojaloop [ %s ] application layer  \n" $app_layer
  delete_mojaloop_layer $app_layer $layer_yaml_dir
  current_dir=`pwd`
  cd $layer_yaml_dir
  yaml_non_dataresource_files=$(ls *.yaml | grep -v '^docker-' | grep -v "\-data\-" )
  yaml_dataresource_files=$(ls *.yaml | grep -v '^docker-' | grep -i "\-data\-" )
  for file in $yaml_dataresource_files; do
      kubectl apply -f $file > /dev/null 2>&1
  done
  for file in $yaml_non_dataresource_files; do
      kubectl apply -f $file > /dev/null 2>&1
  done
  cd $current_dir
  check_pods_are_running "$app_layer"
}

function check_mojaloop_health {
  # verify the health of the deployment 
  for i in "${EXTERNAL_ENDPOINTS_LIST[@]}"; do
    #curl -s  http://$i/health
    if [[ `curl -s  --head --fail --write-out \"%{http_code}\" http://$i/health | \
      perl -nle '$count++ while /\"status\":\"OK+/g; END {print $count}' ` -lt 1 ]] ; then
      printf  " ** Error: [curl -s http://%s/health] endpoint healthcheck failed ** \n" "$i"
      exit 1
    else 
      printf "    ==> curl -s http://%s/health is ok \n" $i 
    fi
    sleep 2 
  done 
}

check_status() {
  local exit_code=$?
  local message="$1"
  local line_number=${BASH_LINENO[0]}

  if [[ $exit_code -ne 0 ]]; then
    echo "Error occurred with exit code $exit_code on line $line_number: $message. Exiting..."
    exit $exit_code
  fi
}

function restore_data {
  error_message=" restoring the mongo database data failed "
  trap 'handle_error $LINENO "$error_message"' ERR
  printf "==> restoring demonstration and test data  \n"
  # temporary measure to inject base participants data into switch 
  mongopod=`kubectl get pods --namespace $NAMESPACE | grep -i mongodb |awk '{print $1}'` 
  mongo_root_pw=`kubectl get secret mongodb -o jsonpath='{.data.mongodb-root-password}'| base64 -d` 
  printf "      - mongodb data  " 
  kubectl cp $ETC_DIR/mongodata.gz $mongopod:/tmp # copy the demo / test data into the mongodb pod
  # run the mongorestore 
  kubectl exec --stdin --tty $mongopod -- mongorestore  -u root -p $mongo_root_pw \
               --gzip --archive=/tmp/mongodata.gz --authenticationDatabase admin > /dev/null 2>&1
  printf " [ ok ] \n"
  error_message=" restoring the testing toolkit data failed  "
  printf "      - testing toolkit data and environment config   " 

  # copy in the bluebank TTK environment data 
  # only need bluebank as we run the TTK from there.
  ## TODO: this neeeds fixing 
  # file_base="$ETC_DIR/ttk/bluebank"
  # file1="dfsp_local_environment.json"
  # file2="hub_local_environment.json"
  # pod_dest="/opt/app/examples/environments" 
  # pod="bluebank-backend-0" 
  # kubectl cp "$file_base/$file1" "$pod:$pod_dest"
  # kubectl cp "$file_base/$file2" "$pod:$pod_dest"
  # kubectl cp "$file_base/$file3" "$pod:$pod_dest"
  # printf " [ ok ] \n"
}

function configure_elastic_search {
  printf "==> configure elastic search "
  # see https://github.com/mojaloop/platform-shared-tools/tree/alpha-1.1/packages/deployment/docker-compose-infra
  if [[ "$MOJALOOP_CONFIGURE_FLAGS_STR" == *"logging"* ]]; then
    audit_json="$REPO_DIR/packages/deployment/docker-compose-infra/es_mappings_logging.json"
    logging_json=$REPO_DIR/packages/deployment/docker-compose-infra/es_mappings_auditing.json
    elastic_password=`grep ES_ELASTIC_PASSWORD $REPO_DIR/packages/deployment/docker-compose-infra/.env.sample | cut -d "=" -f2`

    curl -i --insecure -X PUT "http://elasticsearch.local/ml-logging/" \
        -u elastic:$elastic_password \
        -H "Content-Type: application/json" --data-binary @$logging_json

    curl -i --insecure -X PUT "http://elasticsearch.local/ml-auditing/" \
        -u elastic:$elastic_password \
        -H "Content-Type: application/json" --data-binary @$audit_json
  fi
  printf " [ ok ] \n"
}

function check_urls {
  printf "==> checking URLs are active  \n"
  for url in "${EXTERNAL_ENDPOINTS_LIST[@]}"; do
    if ! [[ $url =~ ^https?:// ]]; then
        url="http://$url"
    fi

    if curl --output /dev/null --silent --head --fail "$url"; then
        if curl --output /dev/null --silent --head --fail --write-out "%{http_code}" "$url" | grep -q "200\|301"; then
            printf "      URL %s  [ ok ]  \n" $url
        else
            printf "    ** Warning: URL %s [ not ok ] \n " $url 
            printf "       (Status code: %s)\n" "$url" "$(curl --output /dev/null --silent --head --fail --write-out "%{http_code}" "$url")"
        fi
    else
        printf "  ** Warning : URL %s is not working.\n" $url 
    fi
  done
}

function print_end_banner {
  printf "\n\n****************************************************************************************\n"
  printf "            -- mini-loop Mojaloop vNext install utility -- \n"
  printf "********************* << END >> ********************************************************\n\n"
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
    printf "%-14s| %s\n" "$key" "${memstats_array[$key]}"
  done
  printf "\n************ mini-loop stats ******************************\n"
}

function print_success_message { 
  #printf " ==> %s configuration of mojaloop deployed ok and passes endpoint health checks \n" "$RELEASE_NAME"
  printf " ==>  mojaloop vNext deployed \n" 
  printf "      no endpoint tests configured yet this is still WIP \n" 
  print_end_banner 
  
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
echo  "USAGE: $0 -m <mode> [-d dns domain] [-n namespace] [-t secs] [-o options] [-f] 
Example 1 : $0 -m install_ml  # install mojaloop (vnext) 
Example 2 : $0 -m install_ml -n namespace1  # install mojaloop (vnext)
Example 3 : $0 -m delete_ml  # delete mojaloop  (vnext)  

Options:
-m mode ............ install_ml|delete_ml
-d domain name ..... domain name for ingress hosts e.g mydomain.com (TBD) 
-n namespace ....... the kubernetes namespace to deploy mojaloop into 
-f force ........... force the cloning and updating of the Mojaloop vNext repo
-t secs ............ number of seconds (timeout) to wait for pods to all be reach running state
-o options(s) .......ml vNext options to toggle on ( logging )
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
MOJALOOP_DEPLOY_TARGET="demo"   # i.e. mini-loop 
HELM_INFRA_RELEASE="infra"
MOJALOOP_BRANCH="k8s_working_br"  # this is the default x64_86 branch
DEFAULT_NAMESPACE="default"
k8s_version=""
K8S_CURRENT_RELEASE_LIST=( "1.26" "1.27" )
LOGFILE="/tmp/miniloop-install.log"
ERRFILE="/tmp/miniloop-install.err"
DEFAULT_TIMEOUT_SECS="1200s"
TIMEOUT_SECS=0
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
ETC_DIR="$( cd $(dirname "$0")/../etc ; pwd )"
REPO_BASE_DIR=$HOME/base  # => so that running an install clones mojaloop to a seperate dir and does not clobber dev work
REPO_DIR=$REPO_BASE_DIR/platform-shared-tools
DEPLOYMENT_DIR=$REPO_DIR/packages/deployment/k8s
INFRA_DIR=$DEPLOYMENT_DIR/infra
CROSSCUT_DIR=$DEPLOYMENT_DIR/crosscut
APPS_DIR=$DEPLOYMENT_DIR/apps
TTK_DIR=$DEPLOYMENT_DIR/ttk
NEED_TO_REPACKAGE="false"
MOJALOOP_CONFIGURE_FLAGS_STR=" -d $REPO_BASE_DIR " 
EXTERNAL_ENDPOINTS_LIST=( vnextadmin bluebank.local greenbank.local ) 
LOGGING_ENDPOINTS_LIST=( elasticsearch.local )
declare -A timer_array
declare -A memstats_array
record_memory_use "at_start"

# Process command line options as required
while getopts "fd:m:t:l:o:hH" OPTION ; do
   case "${OPTION}" in
        n)  nspace="${OPTARG}"
        ;;
        f)  force="true"
        ;;
        l)  logfiles="${OPTARG}"
        ;;
        t)  tsecs="${OPTARG}"
        ;;
        d)  domain_name="${OPTARG}"
            echo "-d flag is TBD"
            exit 1 
        ;; 
        m)  mode="${OPTARG}"
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

echo "$force when first set"
if [[ "$force" == "true" ]]; then
    echo "its true"
    
fi
if [ ! -z "$force" ]; then 
  printf "==> removing existing helm directory\n"
fi 

printf "\n\n****************************************************************************************\n"
printf "            -- mini-loop Mojaloop (vNext) install utility -- \n"
printf "********************* << START  >> *****************************************************\n\n"
check_arch
check_user
set_k8s_distro
set_k8s_version
check_k8s_version_is_current 
set_logfiles 
set_and_create_namespace
set_mojaloop_timeout
printf "\n"

if [[ "$mode" == "delete_ml" ]]; then
  check_deployment_dir_exists
  delete_mojaloop_layer "ttk" $TTK_DIR
  delete_mojaloop_layer "apps" $APPS_DIR
  delete_mojaloop_layer "crosscut" $CROSSCUT_DIR
  delete_mojaloop_infra_release  
  print_end_banner
elif [[ "$mode" == "install_ml" ]]; then
  tstart=$(date +%s)
  printf "start : mini-loop Mojaloop (vNext) install utility [%s]\n" "`date`" >> $LOGFILE
  clone_mojaloop_repo
  configure_extra_options 
  modify_local_mojaloop_yaml_and_charts
  install_infra_from_local_chart
  install_mojaloop_layer "crosscut" $CROSSCUT_DIR 
  install_mojaloop_layer "apps" $APPS_DIR
  install_mojaloop_layer "ttk" $TTK_DIR
  restore_data
  configure_elastic_search
  check_urls

  tstop=$(date +%s)
  telapsed=$(timer $tstart $tstop)
  timer_array[install_ml]=$telapsed
  print_stats
  print_success_message 
else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 