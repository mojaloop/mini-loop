#!/usr/bin/env bash

##
# Bash Niceties
##

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'cleanup  && echo "\"${last_command}\" command filed with exit code $?."' EXIT

# exit on unset vars
set -u

##
# Cleanup 
## 
function cleanup {
  exit_status=$?
  echo 'Cleaning up'  

  exit $exit_status
}

##
# Environment Config
##
MOJALOOP_WORKING_DIR=/vagrant
##TIMEOUT_SECS="2400s"

# run the Setup collection followed by the Golden Path collection of tests 
if [[ ! `su - vagrant -c "helm test fred"` ]] ; then
	  	printf "Error : looks like some tests failed \n"
	    exit 1
	fi
if `su - vagrant -c "helm test fred"` 


# Collect logs and check all Golden Path tests passed 
su - vagrant -c "kubectl logs pod/ml-ml-ttk-test-validation | grep "Passed percentage" | cut -d " " -f5" 