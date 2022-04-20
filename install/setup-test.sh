#!/usr/bin/env bash
# dev test script to setup TD's test env for arm64 automation tooling



################################################################################
# Function: showUsage
################################################################################
# Description:		Display usage message
# Arguments:		none
# Return values:	none
#
function showUsage {
	if [ $# -ne 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: $0 
Example 1 : setup-test.sh -m all 

Options:
-m mode .............all
-h|H ............... display this message
"
	fi
}

################################################################################
# MAIN
################################################################################

##
# Environment Config
##
SCRIPTNAME=$0
WORKING_DIR=$HOME/work
HELM_CHARTS_DIR=$HOME/helm
WIP_HELM_DIR=$HOME/wip-helm

SCRIPT_DIR="$( dirname "${BASH_SOURCE[0]}" )"
REPO_BASE=https://github.com/tdaly61
#REPO_LIST=(central-event-processor central-settlement central-ledger)
export DOCKER_BASE_IMAGE="arm64v8/node:12-alpine"

cd $WORKING_DIR
pwd

# if [ "$EUID" -ne 0 ]
#   then echo "Please run as root"
#   exit 1
# fi

# Check arguments
# if [ $# -lt 1 ] ; then
# 	showUsage
# 	echo "Not enough arguments -m mode must be specified "
# 	exit 1
# fi

# Process command line options as required
while getopts "m:hH" OPTION ; do
   case "${OPTION}" in
        m)	mode="${OPTARG}"
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

printf "\n\n*** Mojaloop -  building arm images and helm charts ***\n\n"
 
# just do the central charts -- to test my text mods
if [[ "$mode" == "central" ]]  ; then
    printf "\n========================================================================================\n"
    printf "Setting up toms dev/test env-- just for central to start with  \n"
    printf "========================================================================================\n"
    rm -rf $WORKING_DIR/*
    cp -r $HELM_CHARTS_DIR/central* $WORKING_DIR
    cp -r $HELM_CHARTS_DIR/arm64-package.sh $WORKING_DIR
    cp -r $WIP_HELM_DIR/kafka  $WORKING_DIR
    cp -r $WIP_HELM_DIR/mysql  $WORKING_DIR
    cp -r $WIP_HELM_DIR/zookeeper  $WORKING_DIR
    cp -r $WIP_HELM_DIR/mongodb $WORKING_DIR
    cp -r $WIP_HELM_DIR/mojaloop $WORKING_DIR
fi 

# copy all the charts and setup to enable chart deployment testing
if [[ "$mode" == "all" ]]  ; then
    printf "\n========================================================================================\n"
    printf "Setting up toms entire MOJALOOP dev/test env \n"
    printf "========================================================================================\n"
    rm -rf $WORKING_DIR/*
    cp -r $HELM_CHARTS_DIR/* $WORKING_DIR
    cp -r $WIP_HELM_DIR/kafka  $WORKING_DIR
    cp -r $WIP_HELM_DIR/mysql  $WORKING_DIR
    cp -r $WIP_HELM_DIR/zookeeper  $WORKING_DIR
    cp -r $WIP_HELM_DIR/mongodb $WORKING_DIR
fi 
