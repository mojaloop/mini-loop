#!/usr/bin/env bash
# k8s-install.sh 
# install microk8s , setup helm and all of the infrastructure ready for mojaloop installation
# Note: curently prepares for ML version 13.x 

# TODO : add command line params to enable selection of which release etc 
#        maybe even allow configuration of microk8s or k3s later from command line 
#       - check the ububntu release using lsb_release -a 
#       - put this into circle-ci and merge with k8s-versions-test.sh so that no code is duplicated
#       - change the ingress port 
#           @see https://discuss.kubernetes.io/t/add-on-ingress-default-port-change-options/14428
#       - Check that python3 and python3-pip installed and ruamel module for python3 (this
#          is required to run mod_charts.py : pip3 install ruamel.yaml )
#   
function check_pi {

    if [ -f "/proc/device-tree/model" ]; then
        model=`cat /proc/device-tree/model | cut -d " " -f 3`
        printf "Warning : hardware is Raspberry PI model : [%s] \n" $model
        printf " for Ubuntu 20 need to append  cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 to /boot/cmdline.txt \n"
        printf " and reboot the PI"     
    fi    
}

function install_prerequisites {
    apt update
    apt install python3-pip
    pip3 install ruamel.yaml

}

function add_hosts {
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : update hosts file \n"
    printf "========================================================================================\n"
    ENDPOINTSLIST=(127.0.0.1   ml-api-adapter.local central-ledger.local account-lookup-service.local account-lookup-service-admin.local 
    quoting-service.local central-settlement-service.local transaction-request-service.local central-settlement.local bulk-api-adapter.local 
    moja-simulator.local sim-payerfsp.local sim-payeefsp.local sim-testfsp1.local sim-testfsp2.local sim-testfsp3.local sim-testfsp4.local 
    mojaloop-simulators.local finance-portal.local operator-settlement.local settlement-management.local testing-toolkit.local 
    testing-toolkit-specapi.local ) 
    export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

    perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
    # TODO check the ping actually works > suggest cloud network rules if it doesn't
    #      also for cloud VMs might need to use something other than curl e.g. netcat ? 
    ping  -c 2 account-lookup-service-admin 
}

function set_k8_version {
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : set k8s version to install (only v1.20 supported right now) \n"
    printf "========================================================================================\n\n"
    if [[ "$k8s_version" == "1.20"  ||  "$k8s_version" == "1.22" ]]  ; then
            printf  " k8s version set correctly to : %s\n" $k8s_version
    else 
            printf "Note -v flag not specified or invalid  => k8s version will use default:  %s \n" $DEFAULT_K8S_VERSION
            k8s_version=$DEFAULT_K8S_VERSION
    fi
}

function do_k8s_install {
    # TODO : Microk8s can complain that This is insecure. Location: /var/snap/microk8s/2952/credentials/client.config
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : Installing Kubernetes and tools (helm etc) \n"
    printf "========================================================================================\n"
    
    echo "==> Mojaloop Microk8s Install: run update ..."
    apt update

    echo "==> Mojaloop Microk8s Install: installing snapd ..."
    apt install snapd -y 

    echo "==> Mojaloop Microk8s Install: installing microk8s release $k8s_version ... "
    snap install microk8s --classic --channel=$k8s_version/stable
    microk8s.status --wait-ready

    echo "==> Mojaloop Microk8s Install: enable helm ... "
    microk8s.enable helm3 
    echo "==> Mojaloop Microk8s Install: enable dns ... "
    microk8s.enable dns
    echo "==> Mojaloop: enable storage ... "
    microk8s.enable storage
    echo "==> Mojaloop: enable ingress ... "
    microk8s.enable ingress

    echo "==> Mojaloop: add convenient aliases..." 
    snap alias microk8s.kubectl kubectl
    snap alias microk8s.helm3 helm

    echo "==> Mojaloop: add $k8s_user user to microk8s group"
    usermod -a -G microk8s $k8s_user
    sudo chown -f -R $k8s_user ~/.kube

}

function add_helm_repos { 
    printf "==> add the helm repos required to install and run Mojaloop version 13.x \n" 
    su - $k8s_user -c "microk8s.helm3 repo add mojaloop http://mojaloop.io/helm/repo/"
    su - $k8s_user -c "microk8s.helm3 repo add kiwigrid https://kiwigrid.github.io"
    su - $k8s_user -c "microk8s.helm3 repo add elastic https://helm.elastic.co"
    su - $k8s_user -c "helm repo add bitnami https://charts.bitnami.com/bitnami"
    su - $k8s_user -c "microk8s.helm3 repo update"

    # TODO  use the helm list and repo list to verify that all the repos got added ok
    #       removed for now to prevent noise
    #su - $k8s_user -c "microk8s.helm3 list"
    #su - $k8s_user -c "microk8s.helm3 repo list"
}

function configure_k8s_user_env { 
    # TODO : Ensure the kubeconfig is setup correctly for the k8s_user 
    # TODO : this is pretty ugly as is appends multiple times to the .bashrc => fix that up
    # TODO : this assumes user is using bash shell 
    # TODO : verify that this all worked ok 
    printf "==> configure $k8s_user k8s environment by adding kubectl nicities to .basrc (bash only for now)  \n" 
    echo "source <(kubectl completion bash)" >> /home/$k8s_user/.bashrc # add autocomplete permanently to your bash shell.
    echo "alias k=kubectl " >> /home/$k8s_user/.bashrc
    echo "complete -F __start_kubectl k " >> /home/$k8s_user/.bashrc
    echo 'alias ksetns="kubectl config set-context --current --namespace"'  >> /home/$k8s_user/.bashrc
    echo "alias ksetuser=\"kubectl config set-context --current --user\""  >> /home/$k8s_user/.bashrc
    
}


function verify_user {
# ensure that the user for k8s exists
        if id -u "$k8s_user" >/dev/null 2>&1 ; then
                return
        else
                printf "    Error: The user [ %s ] does not exist in the operating system \n" $k8s_user
                printf "    mojaloop is the default user for $0 script , you can either create the mojaloop user \n"
                printf "    or specify a (non root) existing user with $0 -u existing_user_name \n"
                exit 1 
        fi
}


function deploy_mojaloop {
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : deploying Mojaloop \n"
    printf "========================================================================================\n\n"

    printf "coming soon"
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
echo  "USAGE: $0 -m [mode] [-v k8 version] [-u user]
Example 1 : version-test.sh -m install -u ubuntu -v 1.20 # install k8s version 1.20
Example 2 : version-test.sh -m remove -u ubuntu -v 1.20 # install k8s version 1.20


Options:
-m mode ............ install|remove (-m is required)
-v k8s version ..... v1.20 (only v1.20 right now )
-u user ............ non root user to run helm and k8s commands and to own mojaloop (default : mojaloop)
-r remove .......... remove k8s insallation (** be cautious using this option) 
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
BASE_DIR=$( cd $(dirname "$0")/../.. ; pwd )
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEFAULT_K8S_VERSION="1.20" # default version to test
DEFAULT_K8S_USER="mojaloop"

# ensure we are running as root 
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Check arguments
if [ $# -lt 1 ] ; then
	showUsage
	echo "Not enough arguments -m mode must be specified "
	exit 1
fi

# Process command line options as required
while getopts "m:v:u:d:hH" OPTION ; do
   case "${OPTION}" in
        d)      chart_dir="${OPTARG}"
        ;;
        m)	    mode="${OPTARG}"
        ;;
        v)	    k8s_version="${OPTARG}"
        ;;
        u)      k8s_user="${OPTARG}"
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



if [[ "$mode" == "install" ]]  ; then
    echo "installing"
    # set the user to run k8s commands
    if [ -z ${k8s_user+x} ] ; then
            k8s_user=$DEFAULT_K8S_USER
    fi
    check_pi  # note microk8s on my pi still has some issues around cgroups 
    verify_user 
    install_prerequisites 
    set_k8_version
    add_hosts
    do_k8s_install
    add_helm_repos 
    configure_k8s_user_env
elif [[ "$mode" == "deploy" ]]  ; then
     deploy_mojaloop
elif [[ "$mode" == "remove" ]]  ; then
    printf "Removing any existing k8s installation \n"
    snap remove microk8s
else 
    showUsage
fi 



