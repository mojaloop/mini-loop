#!/usr/bin/env bash
# this script is testing to see how much of the work to implement ML on arm64 can be automated
# assumes ML repos are safely forked into a separate GitHub Repo and clonable to local environment 




function update_dockerfile {
    printf "Modifying Dockerfile [$1] \n"
    perl -i.bak-1 -pe 's/FROM \S+/FROM $ENV{DOCKER_BASE_IMAGE}/g' $1/Dockerfile
    perl -i -pe 's/python\s/python3 /g' $1/Dockerfile
    perl -i -pe 's/-g node-gyp.*$/-g node-gyp --python=\/usr\/bin\/python3/g' $1/Dockerfile
    perl -i -pe 's/npm ci.*$/npm ci --python=\/usr\/bin\/python3/g' $1/Dockerfile
}

function build_docker_image {
    printf "image for [$1] \n"
    build_image=${GIT_REPO_ARRAY[$1]}
    printf "building docker image [$build_image] \n"
    cd $WORKING_DIR; cd $1
    docker build --no-cache --platform linux/arm64/v8 -t $build_image .
    cd $WORKING_DIR
}

function convert_to_containerd_image {
    build_image=${GIT_REPO_ARRAY[$1]}
    if [ -z "$build_image" ] ; then
        build_image=$1
    fi
    if [  ! "`docker images | grep $build_image `" ] ; then
        printf "Error : Can't find Docker image [%s] => can't convert to containerd \n" "$build_image"
    else 
        #todo make sure microk8s in installed 
        #TODO : how does this work for k3s ? 
        printf "converting image [$build_image] \n"
        DOCKER_SAVE_FILE=/tmp/docker_save.tar
        rm -rf $DOCKER_SAVE_FILE
        docker save $build_image > $DOCKER_SAVE_FILE
        microk8s ctr image import $DOCKER_SAVE_FILE  
    fi
}

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
Example 1 : do_arm64.sh -m all 

Options:
-m mode .............build|convert_images|convert_images_force_replace|update_charts
-i image_name ...... name of the single inage to convert to containerd
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
WORKING_DIR=$HOME/build
HELM_CHARTS_DIR=$HOME/helm
SCRIPT_DIR="$( dirname "${BASH_SOURCE[0]}" )"
REPO_BASE=https://github.com/mojaloop
#REPO_LIST=(central-event-processor central-settlement central-ledger)
export DOCKER_BASE_IMAGE="arm64v8/node:12-alpine"
declare -A GIT_REPO_ARRAY=(
    [account-lookup-service]=account_lookup_service_local
    [als-consent-oracle]=als_consent_oracle_local
    [als-oracle-pathfinder]=als_oracle_pathfinder_local
    [auth-service]=auth_service_local
    [bulk-api-adapter]=buld_api_adapter_local
    [central-event-processor]=central_event_processor_local 
    [central-ledger]=central_ledger_local 
    [central-settlement]=central_settlement_local 
    [email-notifier]=email_notifier_local
    [finance-portal-backend-service]=finance_portal_backend_service_local
    [finance-portal-ui]=finance_portal_ui_local
    [ml-api-adapter]=ml_api_adapter_local 
    [ml-testing-toolkit-ui]=ml_testing_tookit_ui_local
    [ml-testing-toolkit]=ml_test_toolkit_local
    [operator-settlement]=operator_settlement_local
    [quoting-service]=quoting_service_local
    [settlement-management]=settlement_management_local
    [simulator]=simulator_local
    [thirdparty-api-svc]=thirdparty_api_svc_local
    [transaction-requests-service]=transaction_requests_service_local
)

# see below for list of images from grepping helm repo 
# event-sidecar
# mojaloop/central-end-user-registry <--- looks like it is not used , or at least I can't find it's repo in the mojaloop github
# mojaloop/email-notifier <-- used ??
# mojaloop/event-stream-processor  <--used ??
# mojaloop/forensic-logging-sidecar
# mojaloop/ntpd <-- really is this needed ?  What for ? 
# mojaloop/sdk-scheme-adapter
# mojaloop/thirdparty-sdk


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
while getopts "m:i:hH" OPTION ; do
   case "${OPTION}" in
        m)	MODE="${OPTARG}"
        ;;
        i)  IMAGENAME="${OPTARG}"
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

printf "\n\n*** Mojaloop -  building arm images and convert to containerd  ***\n\n"
 
if [[ "$MODE" == "build" ]]  ; then
	printf " running arm updating of ML \n\n"

    for key in  ${!GIT_REPO_ARRAY[@]}; do
        if [ ! -d $key ]; then
            printf "cloning repo: [$REPO_BASE/$key.git] \n"
            git clone $REPO_BASE/$key.git > /dev/null 2>&1
        else 
            printf "repo: [$REPO_BASE/$key.git]  already exists ..skipping clone\n"        
        fi    
    done 

    printf "\n========================================================================================\n"
    printf "Modifying Dockerfiles \n"
    printf "========================================================================================\n"
    for key in  ${!GIT_REPO_ARRAY[@]}; do
        update_dockerfile $key
    done 

    printf "\n========================================================================================\n"
    printf " Building docker images \n"
    printf "========================================================================================\n"
    
    for key in  ${!GIT_REPO_ARRAY[@]}; do
        # don't build if image already exists
        # TODO: add an override flag -force for this 
        #build_docker_image $key
        if [ "`docker images | grep ${GIT_REPO_ARRAY[$key]} `" ] ; then
            printf "found image [%s] so skipping build for now\n" "${GIT_REPO_ARRAY[$key]}"
        else 
            printf "no existing image for [$key] ; building ... "
            build_docker_image $key > /dev/null 2>&1
            if [ "`docker images | grep ${GIT_REPO_ARRAY[$key]} `" ] ; then
                printf "[ok]\n" 
            else
                printf "\nError building docker image for [%s] \n" "${GIT_REPO_ARRAY[$key]}"
            fi
        fi 
    done     

fi 

if [[ "$MODE" == "convert_images" || "$MODE" == "convert_images_force" ]]  ; then
    printf "\n========================================================================================\n"
    printf " Converting docker images to containerd (cri) \n"
    printf "========================================================================================\n"
    if [ ! -z ${IMAGENAME} ] ; then
        printf "converting single image ...\n"
        convert_to_containerd_image $IMAGENAME
    else 
        for key in  ${!GIT_REPO_ARRAY[@]}; do
            if [[ "$MODE" == "convert_images_force" ]] ; then 
                # check to see if containerd image exists already
                printf " this is still WIP \n"
            fi 
            convert_to_containerd_image $key 
        done  
    fi   
fi 
