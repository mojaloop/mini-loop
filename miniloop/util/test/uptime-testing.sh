#!/usr/bin/env bash
# uptime-testing.sh
#  
# This script runs the helm tests continually on a delpoyment of mojaloop 
# it is designed to be run nohup in the background
# for example nohup ./uptime-testing.sh > log.out 2>&1  
# 
# Date Jan 2023 
# Author Tom Daly 

# #!/bin/bash

# # Store the number of times to execute the command in a variable
# read -p "Enter the number of times to execute the command: " num_times

# Use a for loop to repeat the command the specified number of times
function run_test {
    # ==> for testing echo "define fact(n) { if (n == 0) return 1; return n * fact(n-1); }; fact(10000)" | bc > /dev/null 
    helm test ml --logs 
    #echo "define fact(n) { if (n == 0) return 1; return n * fact(n-1); }; fact(10000)" | bc > /dev/null 
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
echo  "USAGE: $0 -n number [-s secs]
Example 1 : $0 -n 2   
Example 3 : $0 -n 200 
 
Options:
-n number ........... number of times to run the helm tests 
-s secs ............. seconds to sleep between runs (default = 30)
-h|H ................ display this message
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
#LOGFILE_BASE_NAME="ml_test"
sleep_secs=60

# Process command line options as required
while getopts "n:s:hH" OPTION ; do
   case "${OPTION}" in
        n)  num_times="$OPTARG"
        ;; 
        s)  sleep_secs="$OPTARG"
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
printf "            -- mini-loop uptime test utility for Mojaloop -- \n"
printf " tool to test kubernetes uptime and processing time of Mojaloop  \n"
printf "              across multiple runs of the TTK GP tests --- \n"
printf "********************* << START  >> *****************************************************\n\n"

# check if the num_times is greater than 1
if [ $num_times -gt 0 ]; then
  printf "\n==> mini-loop Mojaloop uptime test ==> Iterations <%s>  Sleep Secs <%s>  \n" $num_times $sleep_secs
  i=0; 
  for ((i=1; i<=num_times ; i++)); do
    printf " --- Iteration <%s> start --------- \n" "$i"
    time run_test 
    sleep $sleep_secs
  done
  printf "\n --- End: Iterations completed  <%s> \n" $((i-1))
else
  echo "num_times to run the tests should be greater than zero"
fi

