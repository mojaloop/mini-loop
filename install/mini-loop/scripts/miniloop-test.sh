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

function test_k3s_releases {
  ver=$1 
  logfile=$2 
  k8s_user=$3
  printf " processing kubernetes version [v%s] and using logfile [%s]\n" \
            "$ver" "$logfile"
  $SCRIPTS_DIR/../ubuntu/k8s-install.sh -m delete -u ubuntu -k k3s
  $SCRIPTS_DIR/../ubuntu/k8s-install.sh -m install -u ubuntu -k k3s -v $ver 
  su - $k8s_user -c "$SCRIPTS_DIR/miniloop-local-install.sh -m delete_ml -l $logfile" 
  su - $k8s_user -c "$SCRIPTS_DIR/miniloop-local-install.sh -m install_ml -l $logfile -f "
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
Example 1 : $0 -m test_ml
Example 3 : $0 -m test_ml -k k3s 

 
Options:
-m mode ............... test_ml
-k kubernetes distro... microk8s|k3s (default is microk8s)
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
while getopts "k:m:hH" OPTION ; do
   case "${OPTION}" in
        m)  mode="${OPTARG}"
        ;;
        k)  k8s_distro="${OPTARG}"
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

if [[ "$mode" == "test_ml" ]]; then
  printf "ok this is a start \n"
  # for each current release 
  log_numb=0
  for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
    test_k3s_releases "$i" "$LOGFILE_BASE_NAME$log_numb" "ubuntu"
    ((log_numb=log_numb+1))

  done
else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 

