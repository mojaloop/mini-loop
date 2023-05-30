#!/usr/bin/env bash
# vnext-install.sh
#    - install mojaloop vnext version in a light-weight , simple and quick fashion 
#      for demo's testing and development 
#
# refer : @#see @https://github.com/mojaloop/platform-shared-tools            
# Author Tom Daly 
# Date May 2023



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

function check_clone_repo {
  # check if repo eists , clone new if not 
  if [[ ! -d "$REPO_DIR" ]]; then
    printf " cloning repo from https://github.com/mojaloop/platform-shared-tools.git \n"
    git clone https://github.com/mojaloop/platform-shared-tools.git $REPO_DIR
  fi 
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

function iptables_setup { 
  ports_list=( "2181" "5601" "8080" "8081" "9200" "9092" "27017" "443" )
  for i in "${ports_list[@]}"; do
    sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport $i -j ACCEPT
  done
  sudo netfilter-persistent save
}

function mojaloop_infra_setup  {
  printf "start : mini-loop Mojaloop-vnext install base infrastructure services [%s]\n" "`date`"  
  # setup the directory structure and .env file 
  if [[ -d "$INFRA_DIR_EXEC" ]]; then
    printf "** Error: the infra working directory already exists \n"
    printf "** please run cleanup.sh -m delete_ml as root to ensure a clean mojaloop vnext install\n"
    exit 1 
  fi 
  dirs_list=( "certs" "esdata01" "kibanadata" "logs"  "tigerbeetle_data" )
  mkdir $INFRA_DIR_EXEC
  for i in "${dirs_list[@]}"; do
    mkdir "$INFRA_DIR_EXEC/$i"
  done
  cp $INFRA_DIR/.env.sample $INFRA_DIR_EXEC/.env 
  #ls -la $INFRA_DIR_EXEC
  # make sure the ROOT_VOLUME_DEVICE is using absolute path
  perl -p -i -e 's/ROOT_VOLUME_DEVICE_PATH=.*$/ROOT_VOLUME_DEVICE_PATH=$ENV{INFRA_DIR_EXEC}/' $INFRA_DIR_EXEC/.env
  grep ROOT_VOLUME_DEVICE_PATH $INFRA_DIR_EXEC/.env

  iptables_setup

  # provision TigerBeetle's data directory 
  docker run -v $INFRA_DIR_EXEC/tigerbeetle_data:/data ghcr.io/tigerbeetledb/tigerbeetle \
                format --cluster=0 --replica=0 /data/0_0.tigerbeetle
  if [[ $? -eq 0 ]]; then 
        printf "TigerBeetle data directory provisioned correctly\n"
  else 
        printf "** Error : TigerBeetle data directory provisioning appears to have failed ** \n"
        printf "** for now we continue anyhow <== TODO: fix this "
    fi
} 

function mojaloop_infra_svcs_startup {
  printf "==> Mojaloop vNext : infrastructure services startup \n"
  # stop any running infra structure services 
  mojaloop_infra_shutdown

  # start services 
  docker compose -f $INFRA_DIR/docker-compose-infra.yml --env-file $INFRA_DIR_EXEC/.env up -d
  if [[ $? -eq 0 ]]; then 
        printf "mojaloop vNext infrasructure services startup appears ok \n"
  else 
        printf "** Error : infrastructure services startup appears to have failed ** \n"
        printf "** for now we continue anyhow <== TODO: fix this "
  fi
  printf "==> Mojaloop vNext : infrastructure services startup [ok] \n"

  # configure elastic search @TODO: create random password for install and access and look it up from env file 
  # Create the logging index
  es_password=`grep ^ES_ELASTIC_PASSWORD $INFRA_DIR_EXEC/.env | cut -d "=" -f2  | tr -d " "`
  echo "es_password is $es_password"
  curl -i --insecure -X PUT "https://localhost:9200/ml-logging/" -u "elastic" -H "Content-Type: application/json" --data-binary "@$INFRA_DIR/es_mappings_logging.json" --user "elastic:$es_password"
  # Create the auditing index
  curl -i --insecure -X PUT "https://localhost:9200/ml-auditing/" -u "elastic" -H "Content-Type: application/json" --data-binary "@$INFRA_DIR/es_mappings_auditing.json" --user "elastic:$es_password"

  printf "to view the logs for the services run :- \n"
  printf "  $DOCKER_COMPOSE -f $INFRA_DIR/docker-compose-infra.yml --env-file ./.env logs -f \n"  # TODO tidy this up 
}

function  mojaloop_cross_cutting_setup  {
  printf "start : mini-loop Mojaloop-vnext setup cross cutting (i.e. horizontal services)  [%s]\n" "`date`"
  # @see https://github.com/mojaloop/platform-shared-tools/tree/main/packages/deployment/docker-compose-cross-cutting
  # setup the directory structure and .env file 
  if [[ -d "$CROSS_CUT_DIR_EXEC" ]]; then
    printf "** Error: the cross cutting (horizontal services) working directory already exists \n"
    printf "** please run cleanup.sh -m delete_ml as root to ensure a clean mojaloop vnext install\n"
    exit 1 
  fi 
  dirs_list=( "authentication-svc" "authorization-svc" "platform-configuration-svc" "auditing-svc"  "logging-svc" )
  mkdir -p $CROSS_CUT_DIR_EXEC/data 
  for i in "${dirs_list[@]}"; do
    mkdir "$CROSS_CUT_DIR_EXEC/data/$i"
  done
  cp $CROSS_CUT_DIR/.env.sample $CROSS_CUT_DIR_EXEC/.env 
  ls -la $CROSS_CUT_DIR_EXEC/data
  # ensure the ROOT_VOLUME_DEVICE is using absolute path
  perl -p -i -e 's/ROOT_VOLUME_DEVICE_PATH=.*$/ROOT_VOLUME_DEVICE_PATH=$ENV{CROSS_CUT_DIR_EXEC}/' $CROSS_CUT_DIR_EXEC/.env
  grep ROOT_VOLUME_DEVICE_PATH $CROSS_CUT_DIR_EXEC/.env
  # fix what appears to be a typo in the .env.sample file 
  perl -p -i -e 's/^\/\//##/' $CROSS_CUT_DIR_EXEC/.env
} 

function  mojaloop_cross_cutting_svcs_startup {
  printf "==> Mojaloop vNext : cross cutting (horizontal) services startup \n"
  # stop any running infra structure services 
  # mojaloop_cross_cutting_svcs_shutdown   #TODO : this is broken should be part of holistic cleanup maybe separate cleanup script 

  # start cross cutting services 
  $DOCKER_COMPOSE -f $CROSS_CUT_DIR/docker-compose-cross-cutting.yml --env-file $CROSS_CUT_DIR_EXEC/.env  up -d
  if [[ $? -eq 0 ]]; then 
        printf "mojaloop vNext cross cutting (horizontal) services appear to have started ok\n"
  else 
        printf "** Error : infrastructure services startup appears to have failed ** \n"
        printf "** for now we continue anyhow <== TODO: fix this "
  fi
  #printf "==> Mojaloop vNext : infrastructure services startup [ok] \n"
  printf "to view the logs for the services run :- \n"
  printf "  $DOCKER_COMPOSE -f $CROSS_CUT_DIR/docker-compose-cross-cutting.yml  --env-file $CROSS_CUT_DIR_EXEC/.env logs -f \n"  # TODO tidy this up 
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
echo  "USAGE: $0 -m <mode> 
Example 1 : $0 -m install_ml  # install mojaloop (vnext) 
Example 2 : $0 -m delete_ml   # delete mojaloop  (vnext)
 
Options:
-m mode ............ install_ml|delete_ml
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
LOGFILE="/tmp/miniloop-install.log"
ERRFILE="/tmp/miniloop-install.err"
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
REPO_DIR=$HOME/platform-shared-tools
DEPLOYMENT_DIR=$REPO_DIR/packages/deployment/k8s
export INFRA_DIR=$DEPLOYMENT_DIR/infra
export CROSSCUT_DIR=$DEPLOYMENT_DIR/crosscut
export APPS_DIR=$DEPLOYMENT_DIR/apps

# Process command line options as required
while getopts "m:l:hH" OPTION ; do
   case "${OPTION}" in
        l)  logfiles="${OPTARG}"
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

printf "\n\n****************************************************************************************\n"
printf "            -- mini-loop Mojaloop (vNext) install utility -- \n"
printf "********************* << START  >> *****************************************************\n\n"
#check_arch
check_user
#set_logfiles 
printf "\n"

if [[ "$mode" == "delete_ml" ]]; then
  printf "for delete please use cleanup.sh script for now \n"
  exit 1 
  # mojaloop_infra_shutdown
  # #delete_mojaloop
  # print_end_banner
elif [[ "$mode" == "install_ml" ]]; then
  printf "start : mini-loop Mojaloop (vNext) local install utility [%s]\n" "`date`" >> $LOGFILE
#  check_clone_repo 
  mojaloop_infra_setup

else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 