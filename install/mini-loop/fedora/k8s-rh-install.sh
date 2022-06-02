#!/usr/bin/env bash
# k8s-install.sh 
# install kubernetes (currently microk8s)  , setup helm and all of the infrastructure ready for mojaloop installation
# Note: curently prepares for ML version 13.1.x 

# TODO : add command line params to enable selection of which ML release etc 
#        maybe even allow selection of microk8s or k3s later from command line 
#       - put this into circle-ci and merge with k8s-versions-test.sh in charts repo so that little/no code is duplicated
#       - change the ingress port 
#           @see https://discuss.kubernetes.io/t/add-on-ingress-default-port-change-options/14428
#       - Can I make this work for MacOS , other linux or windows ?  Is there any need demand ? 
#   
function check_pi {
    # this is to enable experimentation on raspberry PI which is WIP
    if [ -f "/proc/device-tree/model" ]; then
        model=`cat /proc/device-tree/model | cut -d " " -f 3`
        printf "** Warning : hardware is Raspberry PI model : [%s] \n" $model
        printf " for Ubuntu 20 need to append  cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 to /boot/cmdline.txt \n"
        printf " and reboot the PI ** \n"     
    fi    
}


function check_os_ok {
    printf " ==> check that this os and version is tested with mojaloop (mini-loop scripts)\n"
    ok=false
    # check for redhat family OS 
    # TODO figure out what minimums to support here e.g. RHEL 8 Fedora 36 and Oracle 8 etc 
    if [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ]; then    
        LINUX_OS=`cat /etc/redhat-release | cut -d " " -f1` 
        if [[ "$LINUX_OS" == "Fedora" ]]; then 
            ver=`cat /etc/redhat-release | cut -d " " -f3`
            printf "     Linux Operating System is [Fedora] and version is [%s]\n" "$ver"
            for i in "${FEDORA_OK_VERSIONS_LIST[@]}"; do
                if  [[ "$ver" == "$i" ]]; then
                     ok=true         
                     break
                fi  
            done
        fi
    fi
    # check for Ubuntu 
    if [ -x "/usr/bin/lsb_release" ]; then
        LINUX_OS=`lsb_release --d | perl -ne 'print  if s/^.*Ubuntu.*(\d+).(\d+).*$/Ubuntu/' `
        if [[ $LINUX_OS == "Ubuntu" ]] ; then 
            printf "Identified operating system as %s [ok] \n" $os   
            ver=`/usr/bin/lsb_release --d | perl -ne 'print $&  if m/(\d+)/' `
            for i in "${UBUNTU_OK_VERSIONS_LIST[@]}"; do
                if  [[ "$ver" == "$i" ]]; then
                     ok=true
                     break
                fi  
            done
        fi
    fi

    if [[ "$ok" == "false" ]]; then 
        printf "** Error : This operating system and/or version seems to be untested with mini-loop ** \n" 
        printf "   Tested os types and versions are ... \n" 
        print_ok_oses
        exit 1
    else
        printf "     os and version check  [ok] \n"
    fi 
}

function print_ok_oses {
    printf "      Fedora versions: " 
    for i in "${FEDORA_OK_VERSIONS_LIST[@]}"; do
        printf " [%s]" "$i"
    done
    printf "\n"
    printf "      Ubuntu versions: " 
    for i in "${UBUNTU_OK_VERSIONS_LIST[@]}"; do
        printf " [%s]" "$i"
    done
    printf "\n"
}

function install_prerequisites {
    printf " ==> installing prerequisites for [%s] \n" "$LINUX_OS"
    if [[ "$LINUX_OS" == "Fedora" ]]; then 
        dnf install snapd -y 
        ln -s /var/lib/snapd/snap /snap
        # yum update -y 
        # yum install -y snapd
        # systemctl enable --now snapd.socket
        # ln -s /var/lib/snapd/snap /snap
    fi 
    if [[ "$LINUX_OS" == "ubuntu" ]]; then 
        apt update -y 
        apt install snapd -y 
        apt install -y python3-pip
    fi 
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
    # TODO : ISSUE a big warning if the ping fails 
    ping  -c 2 account-lookup-service-admin.local
}

function set_k8_version {
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : set k8s version to install (default and minimum is 1.20) \n"
    printf "========================================================================================\n\n"
    if [[ "$k8s_version" == "1.20" ]]  ; then
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
}

function configure_k8s_user_env { 
    # TODO : this is pretty ugly as if it is re-run it appends multiple times to the .bashrc => fix that up
    # TODO : this assumes user is using bash shell 
    printf "==> configure kubernetes environment for user [%s] by adding kubectl utilities to .basrc (bash only for now) [ok]  \n" "$k8s_user" 
    echo "source <(kubectl completion bash)" >> /home/$k8s_user/.bashrc # add autocomplete permanently to your bash shell.
    echo "alias k=kubectl " >> /home/$k8s_user/.bashrc
    echo "complete -F __start_kubectl k " >> /home/$k8s_user/.bashrc
    echo 'alias ksetns="kubectl config set-context --current --namespace"'  >> /home/$k8s_user/.bashrc
    echo "alias ksetuser=\"kubectl config set-context --current --user\""  >> /home/$k8s_user/.bashrc    
}

function verify_user {
# ensure that the user for k8s exists
        if [[ -z "$k8s_user" ]]; then 
            printf "    Error: The operating system user has not been specified with the -u flag \n" 
            printf "           the user specified with the -u flag must exist and not be the root user \n" 
            exit 1
        fi

        if id -u "$k8s_user" >/dev/null 2>&1 ; then
                return
        else
                printf "    Error: The user [ %s ] does not exist in the operating system \n" $k8s_user
                printf "            please try again and specify an existing user \n"
                exit 1 
        fi    
}

function check_k8s_installed { 
    k8s_ready=`su - $k8s_user -c "kubectl get nodes" | perl -ne 'print  if s/^.*Ready.*$/Ready/'`
    if [[ ! "$k8s_ready" == "Ready" ]]; then 
        printf "** Error : kubernetes is not installed , please run $0 -m install -u $k8s_user \n"
        printf "           before trying to install mojaloop \n "
        exit 1 
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
echo  "USAGE: $0 -m [mode] -u [ user] [-v k8 version]
Example 1 : k8s-install.sh -m install -u ubuntu -v 1.20 # install k8s version 1.20
Example 2 : k8s-install.sh -m remove -u ubuntu -v 1.20 # install k8s version 1.20


Options:
-m mode ............ install|remove (-m is required)
-v k8s version ..... 1.20 (default : 1.20 only right now due to  https://github.com/mojaloop/project/issues/2447 )
-u user ............ non root user to run helm and k8s commands and to own mojaloop (default : mojaloop) 
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
RUN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # the directory that this script is run from 
SCRIPTS_DIR="$( cd $(dirname "$0")/../scripts ; pwd )"
LINUX_OS="" 

echo $BASE_DIR
echo $RUN_DIR
echo $SCRIPTS_DIR


DEFAULT_K8S_VERSION="1.20" # default version to test
#DEFAULT_K8S_USER="mojaloop"
UBUNTU_OK_VERSIONS_LIST=(16 18 20 )
FEDORA_OK_VERSIONS_LIST=( 36 )
REDHAT_OK_VERSIONS_LIST=( 8 )

# ensure we are running as root 
# if [ "$EUID" -ne 0 ]
#   then echo "Please run as root"
#   exit 1
# fi

# Check arguments
if [ $# -lt 1 ] ; then
	showUsage
	echo "Not enough arguments -m mode must be specified "
	exit 1
fi

# Process command line options as required
while getopts "m:v:u:hH" OPTION ; do
   case "${OPTION}" in
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
    check_os_ok # check this is an ubuntu OS v18.04 or later 
    #@jason removed for now: [set_linux_os] function not avail
    verify_user 
    install_prerequisites 
    set_k8_version
    add_hosts
    do_k8s_install
    add_helm_repos 
    configure_k8s_user_env
    printf "==> The kubernetes environment is now configured for user [%s] and ready for mojaloop deployment \n" "$k8s_user"
    printf "    To deploy mojaloop, please su - %s from root or login as user [%s] and then \n"  "$k8s_user" "$k8s_user"
    printf "    execute the %s/01_install_miniloop.sh script \n"  "$SCRIPTS_DIR"    
elif [[ "$mode" == "remove" ]]  ; then
    printf "Removing any existing k8s installation \n"
    snap remove microk8s
else 
    showUsage
fi 



