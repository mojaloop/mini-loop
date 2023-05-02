#!/usr/bin/env bash
# miniloop-test.sh
#               - high level test script to test mini-loop install of Mojaloop
#                 across multiple k8s versions and both k3s and microk8s 
#                 kubernetes distributions 
#         
# Date July 2022
# Author Tom Daly 
# Updated May 2023 to use mini-loop v5.0 

# ensure we are running as root 
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

function get_user {
  # set the k8s_user 
  k8s_user=`who am i | cut -d " " -f1`
}


function set_k8s_distro { 
    if [ -z ${k8s_distro+x} ]; then 
      printf " ** Error: use -k flag to choose microk8s or k3s or both (to test both k8s engines) \n"
      exit 1
    fi    
    k8s_distro=`echo "$k8s_distro" | perl -ne 'print lc'`
    if [[ "$k8s_distro" == "microk8s" ]]  || [[ "$k8s_distro" == "k3s" ]]; then 
        printf "miniloop-test>> testing kubernetes distribution [%s] \n" "$k8s_distro"
    elif  [[ "$k8s_distro" == "both" ]]; then 
        printf "miniloop-test>> testing both k3s and microk8s kubernetes distributions \n" 
    else 
        printf " ** Error: kubernetes distro must be microk8s or k3s or both (to test both k8s engines) \n"
        exit 1 
    fi 
}

function test_k8s_releases {
  k8s_user=$1
  log_base=$2
  k8s=$3
  log_numb=0
  

  # test k8s releases 
  for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
    logfile="$log_base"_"$k8s"_"$log_numb"
    printf "###################################################################################################\n"
    printf "start_miniloop-test>>  processing kubernetes distro [%s] version [v%s] and using logfile [%s]\n" \
             "$k8s" "$i" "$logfile"

    $SCRIPTS_DIR/k8s-install.sh -m delete -k $k8s
    echo "  $SCRIPTS_DIR/k8s-install.sh  -m install -k $k8s -v $i"
    $SCRIPTS_DIR/k8s-install.sh  -m install -k $k8s -v $i
    if [[ $? -ne 0 ]]; then 
        printf "miniloop-test>> Error k8s distro [%s] version [%s] failed to install cleanly \n" "$k8s" "$i"
        printf "               skipping this release \n"
    else 
      su - $k8s_user -c "$SCRIPTS_DIR/mojaloop-install.sh -m delete_ml -l $logfile" 
      su - $k8s_user -c "$SCRIPTS_DIR/mojaloop-install.sh -m install_ml -l $logfile -f"
      su - $k8s_user -c "$SCRIPTS_DIR/mojaloop-install.sh -m check_ml -l $logfile "
    fi 

    if [ ! -z ${helm_test+x} ]; then  
        printf "miniloop-test>> -t specified so helm test will be run \n" 
        ## assume deployment name of ML and default namespace for now 
        su - $k8s_user -c "helm test ml --logs" >> $logfile 2>&1
    fi 
    ((log_numb=log_numb+1))
    printf "end_miniloop-test>> processing kubernetes distro [%s] version [v%s] and using logfile [%s]\n" \
             "$k8s" "$i" "$logfile"
    printf "###################################################################################################\n"
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
	if [ $# -lt 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: sudo $0 -m <mode> -k <k8s distro(s)> [-t]
Example 1 : $0 -m test_ml            # test both microk8s and k3s using user mluser 
Example 3 : $0 -m test_ml -k k3s     # test k3s 

 
Options:
-m mode ............... test_ml
-k kubernetes distro... microk8s|k3s|both (scope of tests)
-t .................... run helm tests  
-h|H .................. display this message
"
	fi
}

################################################################################
# MAIN
################################################################################

##
# Environment Config & global vars 
##
SCRIPTS_DIR="$( cd $(dirname "$0")/../../scripts ; pwd )"
K8S_VERSION="" 
K8S_CURRENT_RELEASE_LIST=( "1.26" "1.27" )
LOGFILE_BASE_NAME="ml_test"
k8s_user=""


# Process command line options as required
while getopts "k:m:u:thH" OPTION ; do
   case "${OPTION}" in
        m)  mode="${OPTARG}"
        ;;
        k)  k8s_distro="${OPTARG}"
        ;; 
        t)  helm_test="true"
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
printf "            -- mini-loop test utility -- \n"
printf " tool to test kubernetes install/config and miniloop install \n"
printf "              across multiple k8s releases \n"
printf "********************* << START  >> *****************************************************\n\n"

get_user
set_k8s_distro

if [[ "$mode" == "test_ml" ]]; then 
  if [[ $k8s_distro == "k3s" ]] || [[ $k8s_distro == "both" ]]; then 
    # delete any installed microk8s before we start 
    $SCRIPTS_DIR/k8s-install.sh -m delete -k microk8s > /dev/null 2>&1
    test_k8s_releases "$k8s_user" "$LOGFILE_BASE_NAME" "k3s"
  fi 
  if [[ $k8s_distro == "microk8s" ]] || [[ $k8s_distro == "both" ]]; then
    # delete any installed k3s before we start  
    $SCRIPTS_DIR/k8s-install.sh -m delete -k k3s  > /dev/null 2>&1
    test_k8s_releases "$k8s_user" "$LOGFILE_BASE_NAME" "microk8s"
  fi 

  printf "********************* << successful end  >> *****************************************************\n\n"
else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 

