#!/usr/bin/env bash
# miniloop-test.sh
#               - high level test script to test mini-loop install of Mojaloop
#                 across multiple k8s versions and both k3s and microk8s 
#                 kubernetes distributions 
#         
# Date July 2022
# Author Tom Daly 

# ensure we are running as root 
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

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
    logfile="$log_base$log_numb"
    printf "miniloop-test>> processing kubernetes distro [%s] version [v%s] and using logfile [%s]\n" \
             "$k8s" "$i" "$logfile"

    $SCRIPTS_DIR/../scripts/k8s-install-current.sh -m delete -u $k8s_user -k $k8s
    echo "  $SCRIPTS_DIR/../scripts/k8s-install-current.sh -m install -u $k8s_user -k $k8s -v $i"
    $SCRIPTS_DIR/../scripts/k8s-install-current.sh -m install -u $k8s_user -k $k8s -v $i
    if [[ $? -ne 0 ]]; then 
        printf "miniloop-test>> Error k8s distro [%s] version [%s] failed to install cleanly \n" "$k8s" "$i"
        printf "               skipping this release \n"
    else 
      su - $k8s_user -c "$SCRIPTS_DIR/miniloop-local-install.sh -m delete_ml -l $logfile" 
      su - $k8s_user -c "$SCRIPTS_DIR/miniloop-local-install.sh -m install_ml -l $logfile -f"
      su - $k8s_user -c "$SCRIPTS_DIR/miniloop-local-install.sh -m check_ml -l $logfile "
    fi 

    if [ ! -z ${helm_test+x} ]; then  
        printf "miniloop-test>> -t specified so helm test will be run \n" 
        ## assume deployment name of ML and default namespace for now 
        su - $k8s_user -c "helm test ml --logs" >> $logfile 2>&1
    fi 
    ((log_numb=log_numb+1))
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
echo  "USAGE: $0 -m <mode> -u <user> -k <k8s distro(s)> [-t]
Example 1 : $0 -m test_ml -u mluser # test both microk8s and k3s using user mluser 
Example 3 : $0 -m test_ml -k -u user k3s 

 
Options:
-m mode ............... test_ml
-k kubernetes distro... microk8s|k3s|both (scope of tests)
-u user ............... non root user to run helm and k8s commands and to own mojaloop deployment
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
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
K8S_VERSION="" 
K8S_CURRENT_RELEASE_LIST=( "1.22" "1.23" "1.24" )
LOGFILE_BASE_NAME="ml_test"


# Process command line options as required
while getopts "k:m:u:thH" OPTION ; do
   case "${OPTION}" in
        m)  mode="${OPTARG}"
        ;;
        k)  k8s_distro="${OPTARG}"
        ;;
        u)  k8s_user="${OPTARG}"
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

set_k8s_distro

if [[ "$mode" == "test_ml" ]]; then 
  if [[ $k8s_distro == "k3s" ]] || [[ $k8s_distro == "both" ]]; then 
    # delete any installed microk8s before we start 
    $SCRIPTS_DIR/../scripts/k8s-install-current.sh -m delete -u $k8s_user -k microk8s 
    test_k8s_releases "$k8s_user" "$LOGFILE_BASE_NAME" "k3s"
  fi 
  if [[ $k8s_distro == "microk8s" ]] || [[ $k8s_distro == "both" ]]; then
    # delete any installed k3s before we start  
    $SCRIPTS_DIR/../scripts/k8s-install-current.sh -m delete -u $k8s_user -k k3s 
    test_k8s_releases "$k8s_user" "$LOGFILE_BASE_NAME" "microk8s"
  fi 

  printf "********************* << successful end  >> *****************************************************\n\n"
else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 

