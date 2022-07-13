#!/usr/bin/env bash
# miniloop-test.sh
#               - high level test script to test mini-loop install of Mojaloop
#                 across multiple k8s versions and both k3s and microk8s 
#                 kubernetes distributions 
#         
# Date July 2022

function check_user {
  # ensure that the user is not root
  if [ "$EUID" -eq 0 ]; then 
    printf " ** Error: please run $0 as non root user ** \n"
    exit 1
  fi
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
function showUsage {
	if [ $# -lt 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: $0 -m <mode> 
Example 1 : $0 -m test_ml
Example 3 : $0 -m test_ml -k k3s 

 
Options:
-m mode ............... install_ml|delete_ml|install_db|delete_db 
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
ETC_DIR="$( cd $(dirname "$0")/../etc ; pwd )"
NEED_TO_REPACKAGE="false"
#ML_VALUES_FILE="miniloop_values.yaml"

# Process command line options as required
while getopts "dfst:n:m:hH" OPTION ; do
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
printf"              across multiple k8s releases \n"
printf "********************* << START  >> *****************************************************\n\n"
check_arch
check_user
rm $LOGFILE >> /dev/null 2>&1
rm $ERRFILE >> /dev/null 2>&1
set_and_create_namespace
set_k8s_distro
set_mojaloop_timeout
printf "\n"

if [[ "$mode" == "install_db" ]]; then
  install_db
  print_end_banner
elif [[ "$mode" == "delete_db" ]]; then
  delete_db
  print_end_banner
elif [[ "$mode" == "delete_ml" ]]; then
  delete_mojaloop_helm_chart
  print_end_banner
elif [[ "$mode" == "install_ml" ]]; then
  clone_helm_charts_repo
  modify_local_helm_charts
  if [ -z ${skip_repackage+x} ]; then 
    repackage_charts
  fi
  #set_mojaloop_values_file
  install_mojaloop_from_local
  check_deployment_health
  print_success_message 
else 
  printf "** Error : wrong value for -m ** \n\n"
  showUsage
  exit 1
fi 

