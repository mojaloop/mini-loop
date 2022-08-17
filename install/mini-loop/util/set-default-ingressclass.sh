#!/usr/bin/env bash
# dev test script to setup to figure out how to 
# ensure that there is a default ingressclass set
# Microk8s for instance sets a default ingressclass name=public but
# k3s does not set a default
# this script is going to figure out if 


kubectl get ingressclass -A | grep -iv NAME |head -1 | cut -d" " -f1


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
-m mode .............run
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
echo $SCRIPT_DIR 


# Process command line options as required
while getopts "hH" OPTION ; do
   case "${OPTION}" in
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
    printf " running fix_ingress_db.py and package.sh "
    printf "========================================================================================\n"
    printf " ==> clear [%s] directory  \n" "$WORKING_DIR"
    rm -rf $WORKING_DIR/* > /dev/null 2>&1 
    printf " ==> copying all of  [%s] directory into [%s] directory \n" "$HELM_CHARTS_DIR", "$WORKING_DIR"
    cp -r $HELM_CHARTS_DIR/* $WORKING_DIR > /dev/null 2>&1 
    printf " ==> running fix_ingress_db.py -d %s -i \n" "$WORKING_DIR"
    $SCRIPT_DIR/fix_ingress_db.py -d $WORKING_DIR -i 
    printf " ==> running package.sh \n"
    cd $WORKING_DIR
    ./package.sh 
    cd $HOME
    # cp -r $WIP_HELM_DIR/kafka  $WORKING_DIR
    # cp -r $WIP_HELM_DIR/mysql  $WORKING_DIR
    # cp -r $WIP_HELM_DIR/zookeeper  $WORKING_DIR
    # cp -r $WIP_HELM_DIR/mongodb $WORKING_DIR
fi 
