#!/usr/bin/env bash
# k8s-install-current.sh 
# based on the older k8s-install.sh this script will only install current versions of kubernetes
# Author:  Tom Daly 
# Date : July 2022 

# TODO : add command line params to enable selection of which ML release etc 
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

function check_arch_ok {
    if [[ ! "$k8s_arch" == "x86_64" ]]; then 
        printf " **** Warning : mini-loop only works properly with x86_64 today *****\n"
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

function k8s_already_installed {  
    if [[ -f "/usr/local/bin/k3s" ]]; then 
        printf "** Error , k3s is already installed , please delete before reinstalling kubernetes  **\n"
        exit 1
    fi 
    #check to ensure microk8s isn't already installed when installing k3s
    if [[ -f "/snap/bin/microk8s" ]]; then 
        printf "** Error , microk8s is already installed, please delete before reinstalling kubernetes  **\n"
        exit 1
    fi 
}

function check_is_linux {
    is_linux=false
    if [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ] \
       || [ -f /etc/os-release ] || [ -x "/usr/bin/lsb_release" ]; then
        is_linux=true
    else
        printf " ** ERROR: could not determine that this is a Linux OS \n"
        printf "    currently mini-loop only works on Linux OS  \n"
        exit 1 
    fi
}

function check_os_ok {
    check_is_linux # exit if it seems not to be linux 
    printf "==> check OS and kubernetes distro is tested with mini-loop scripts\n"
    ok=false

    # check for Ubuntu 
    if [ -x "/usr/bin/lsb_released" ]; then
        LINUX_OS=`lsb_release --d | perl -ne 'print  if s/^.*Ubuntu.*(\d+).(\d+).*$/Ubuntu/' `
        if [[ $LINUX_OS == "Ubuntu" ]] ; then 
            printf "    identified operating system as %s [ok] \n" $LINUX_OS   
            ver=`/usr/bin/lsb_release --d | perl -ne 'print $&  if m/(\d+)/' `
            # for i in "${UBUNTU_OK_VERSIONS_LIST[@]}"; do
            #     if  [[ "$ver" == "$i" ]]; then
            #          ok=true
            #          break
            #     fi  
            # done
        fi
    else 
        if [[ "$k8s_distro" == "microk8s" ]]; then 
            printf "  ** Error: OS is not Ubuntu and microk8s has not been reliably tested with mini-loop except on Ubuntu OS \n"
            printf "  ** please use -k k3s (or omit -k flag) to use k3s on this linux OS \n"
            exit 1 
        fi
    fi

} 

function install_prerequisites {
    printf "==> Install any OS prerequisites , tools &  updates  ...\n"
    if [[ $LINUX_OS == "Ubuntu" ]]; then  
        printf "   apt update \n"
        apt update > /dev/null 2>&1
        printf "    python and python libs ...\n"
        apt install python3-pip -y 
        pip3 install ruamel.yaml
        if [[ $k8s_distro == "microk8s" ]]; then 
            printf "   install snapd\n"
            apt install snapd -y > /dev/null 2>&1
        fi
    fi 
    # todo what about non ubuntu, still want python3 and ruamel ? 
}

function add_hosts {
    printf "==> Mojaloop k8s install : update hosts file \n"
    ENDPOINTSLIST=(127.0.0.1   ml-api-adapter.local central-ledger.local account-lookup-service.local account-lookup-service-admin.local 
    quoting-service.local central-settlement-service.local transaction-request-service.local central-settlement.local bulk-api-adapter.local 
    moja-simulator.local sim-payerfsp.local sim-payeefsp.local sim-testfsp1.local sim-testfsp2.local sim-testfsp3.local sim-testfsp4.local 
    mojaloop-simulators.local finance-portal.local operator-settlement.local settlement-management.local testing-toolkit.local 
    testing-toolkit-specapi.local ) 
    export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

    perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
    # TODO check the ping actually works > suggest cloud network rules if it doesn't
    #      also for cloud VMs might need to use something other than curl e.g. netcat ? 
    ping  -c 2 account-lookup-service-admin.local
}

function set_k8s_distro { 

    if [ -z ${k8s_distro+x} ]; then  
        k8s_distro=$DEFAULT_K8S_DISTRO
        printf "==> Using default kubernetes distro [%s]\n" "$k8s_distro"
    else 
        k8s_distro=`echo "$k8s_distro" | perl -ne 'print lc'`
        if [[ "$k8s_distro" == "microk8s" || "$k8s_distro" == "k3s" ]]; then 
            printf "==> kubernetes distro set to [%s] \n" "$k8s_distro"
        else 
            printf "** Error : invalid kubernetes distro specified. Valid options are microk8s or k3s \n"
            exit 1
        fi
    fi
}

function print_current_k8s_releases {
    printf "          Current Kubernetes releases are : " 
    for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
        printf " [v%s]" "$i"
    done
    printf "\n"
}

function set_k8s_version {
    # printf "========================================================================================\n"
    # printf " set the k8s version to install  \n"
    # printf "========================================================================================\n\n"
    # Users who want to run non-current versions of kubernetes will need to use mini-loop version 3.0 and 
    # or the older script in ubuntu directory for as long as it is included in current versions of mini-loop
    # (which might not be too long)
    if [ ! -z ${k8s_user_version+x} ] ; then
        # strip off any leading characters
        k8s_user_version=`echo $k8s_user_version |  tr -d A-Z | tr -d a-z `
        for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
            if  [[ "$k8s_user_version" == "$i" ]]; then
                CURRENT_RELEASE=true
                break
            fi  
        done
        if [[ $CURRENT_RELEASE == true ]]; then     
            K8S_VERSION=$k8s_user_version
        else 
            printf "** Error: The specified kubernetes release [ %s ] is not a current release \n" "$k8s_user_version"
            printf "          when using the -v flag you must specify a current supported release \n"
            print_current_k8s_releases 
            printf "** \n"
            exit 1 
        fi 
    else 
        printf "** Error: kubernetes release has not been specified with the -v flag  \n" 
        printf "          you must supply the -v flag and specify a current supported release \n\n"
        showUsage
        exit 1
    fi 
    printf "==> kubernetes version to install set to [%s] \n" "$K8S_VERSION"
}

function do_microk8s_install {
    # TODO : Microk8s can complain that This is insecure. Location: /var/snap/microk8s/2952/credentials/client.config
    printf "==> Installing Kubernetes MicroK8s & enabling tools (helm,ingress  etc) \n"

    echo "==> Mojaloop Microk8s Install: installing microk8s release $k8s_user_version ... "
    # ensure k8s_user has clean .kube/config 
    rm -rf $k8s_user_home/.kube >> /dev/null 2>&1 

    snap install microk8s --classic --channel=$K8S_VERSION/stable
    microk8s.status --wait-ready

    #echo "==> Mojaloop Microk8s Install: enable helm ... "
    microk8s.enable helm3 
    #echo "==> Mojaloop Microk8s Install: enable dns ... "
    microk8s.enable dns
    echo "==> Mojaloop: enable storage ... "
    microk8s.enable storage
    #echo "==> Mojaloop: enable ingress ... "
    microk8s.enable ingress

    echo "==> Mojaloop: add convenient aliases..." 
    snap alias microk8s.kubectl kubectl
    snap alias microk8s.helm3 helm

    echo "==> Mojaloop: add $k8s_user user to microk8s group"
    usermod -a -G microk8s $k8s_user

    # ensure .kube/config points to this new cluster and KUBECONFIG is not set in .bashrc
    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bashrc
    chown -f -R $k8s_user $k8s_user_home/.kube
    microk8s config > $k8s_user_home/.kube/config

}

function do_k3s_install {
    printf "========================================================================================\n"
    printf "Mojaloop k3s install : Installing Kubernetes k3s engine and tools (helm/ingress etc) \n"
    printf "========================================================================================\n"

    # ensure k8s_user has clean .kube/config 
    rm -rf $k8s_user_home/.kube >> /dev/null 2>&1 
    printf "=> installing k3s \n"
    echo $K8S_VERSION
    curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                            INSTALL_K3S_CHANNEL=$K8S_VERSION \
                            INSTALL_K3S_EXEC=" --no-deploy traefik " sh 
    
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    cp /etc/rancher/k3s/k3s.yaml  $k8s_user_home/k3s.yaml
    chown $k8s_user  $k8s_user_home/k3s.yaml
    chmod 600  $k8s_user_home/k3s.yaml 

    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bashrc
    echo "export KUBECONFIG=\$HOME/k3s.yaml" >>  $k8s_user_home/.bashrc

    perl -p -i.bak -e 's/^.*source .bashrc.*$//g' $k8s_user_home/.bash_profile 
    perl -p  -e 's/^.*export KUBECONFIG.*$//g' $k8s_user_home/.bash_profile 
    echo "source .bashrc" >>   $k8s_user_home/.bash_profile 
    echo "export KUBECONFIG=\$HOME/k3s.yaml" >>   $k8s_user_home/.bash_profile  
    
    # install helm
    printf "==> installing helm " 
    helm_arch_str=""
    if [[ "$k8s_arch" == "x86_64" ]]; then 
        helm_arch_str="amd64"
    elif [[ "$k8s_arch" == "aarch64" ]]; then 
        helm_arch_str="arm"
    else 
        printf "** Error:  architecture not recognised as x86_64 or arm64  ** \n"
        exit 1
    fi
    rm -rf /tmp/linux-$helm_arch_str /tmp/helm.tar
    curl -L -s -o /tmp/helm.tar.gz https://get.helm.sh/helm-v$HELM_VERSION-linux-$helm_arch_str.tar.gz
    gzip -d /tmp/helm.tar.gz 
    tar xf  /tmp/helm.tar -C /tmp
    mv /tmp/linux-amd64/helm /usr/local/bin  
    rm -rf /tmp/linux-$helm_arch_str
    /usr/local/bin/helm version > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then 
        printf "[ok]\n"
    else 
        printf "** Error : helm install seems to have failed ** \n"
        exit 1
    fi
    
    #install nginx
    printf "==> installing ingress chart and wait for it to be ready\n" 
    su - $k8s_user -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx" 
    # TODO : check to ensure that the ingress is indeed running 
}

function install_k8s_tools { 
    printf "==> install kubernetes tools, kubens, kubectx kustomize \n" 
    curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubens_v0.9.4_linux_x86_64.tar.gz| gzip -d -c | tar xf - 
    mv ./kubens /usr/local/bin > /dev/null 2>&1
    curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx_v0.9.4_linux_x86_64.tar.gz | gzip -d -c | tar xf -
    mv ./kubectx /usr/local/bin > /dev/null
    
    # install kustomize
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
    mv ./kustomize /usr/local/bin > /dev/null 2>&1
}

function add_helm_repos { 
    printf "==> add the helm repos required to install and run Mojaloop version 13.x \n" 
    su - $k8s_user -c "helm repo add kiwigrid https://kiwigrid.github.io" > /dev/null 2>&1
    su - $k8s_user -c "helm repo add elastic https://helm.elastic.co" > /dev/null 2>&1
    su - $k8s_user -c "helm repo add bitnami https://charts.bitnami.com/bitnami" > /dev/null 2>&1
    su - $k8s_user -c "helm repo add mojaloop http://mojaloop.io/helm/repo/" > /dev/null 2>&1
    su - $k8s_user -c "helm repo update" > /dev/null 2>&1
}

function configure_k8s_user_env { 
    start_message="# start of config added by mini-loop #"
    grep "start of config added by mini-loop" $k8s_user_home/.bashrc >/dev/null 2>&1
    if [[ $? -ne 0  ]]; then 
        printf "==> Adding configuration for %s to %s .bashrc\n" "$k8s_distro" "$k8s_user"
        printf "%s\n" "$start_message" >> $k8s_user_home/.bashrc 
        echo "source <(kubectl completion bash)" >> $k8s_user_home/.bashrc # add autocomplete permanently to your bash shell.
        echo "alias k=kubectl " >>  $k8s_user_home/.bashrc
        echo "complete -F __start_kubectl k " >>  $k8s_user_home/.bashrc
        echo "alias ksetns=\"kubectl config set-context --current --namespace\" " >>  $k8s_user_home/.bashrc
        echo "alias ksetuser=\"kubectl config set-context --current --user\" "  >>  $k8s_user_home/.bashrc 
        echo "alias cdml=\"cd $k8s_user_home/mini-loop/install/mini-loop\" " >>  $k8s_user_home/.bashrc 
        printf "# end of config added by mini-loop #\n" >> $k8s_user_home/.bashrc 
    else 
        printf "==> Configuration for .bashrc for %s for user %s already exists ..skipping\n" "$k8s_distro" "$k8s_user"
    fi
}

function verify_user {
# ensure that the user for k8s exists
        if [ -z ${k8s_user+x} ]; then 
            printf "** Error: The operating system user has not been specified with the -u flag \n" 
            printf "          the user specified with the -u flag must exist and not be the root user \n" 
            printf "** \n"
            exit 1
        fi

        if [[ `id -u $k8s_user >/dev/null 2>&1` == 0 ]]; then 
            printf "** Error: The user specified by -u should be a non-root user ** \n"
            exit 1
        fi 

        if id -u "$k8s_user" >/dev/null 2>&1 ; then
            k8s_user_home=`eval echo "~$k8s_user"`
            return
        else
            printf "** Error: The user [ %s ] does not exist in the operating system \n" $k8s_user
            printf "            please try again and specify an existing user \n"
            printf "** \n"
            exit 1 
        fi    
}

function delete_k8s {
    if [[ "$k8s_distro" == "microk8s" ]]; then 
        printf "==> removing any existing Microk8s installation "
        snap remove microk8s > /dev/null 2>&1
        if [[ $? -eq 0  ]]; then 
            printf " [ ok ] \n"
        else 
            printf " [ microk8s delete failed ] \n"
            printf "** was microk8s installed ?? \n" 
            printf "   if so please try running \"sudo snap remove microk8s\" manually ** \n"
        fi
    else 
        printf "==> removing any existing k3s installation and helm binary"
        rm /usr/local/bin/helm >> /dev/null 2>&1
        /usr/local/bin/k3s-uninstall.sh >> /dev/null 2>&1
        if [[ $? -eq 0  ]]; then 
            printf " [ ok ] \n"
        else 
            printf " [ k3s delete failed ] \n"
            printf "** was k3s installed ?? \n" 
            printf "   if so please try running \"/usr/local/bin/k3s-uninstall.sh\" manually ** \n"
        fi
    fi     
}

function check_k8s_installed { 
    printf "==> Check the cluster is available and ready from kubectl  "
    k8s_ready=`su - $k8s_user -c "kubectl get nodes" | perl -ne 'print  if s/^.*Ready.*$/Ready/'`
    if [[ ! "$k8s_ready" == "Ready" ]]; then 
        printf "** Error : kubernetes is not installed , please run $0 -m install -u $k8s_user \n"
        printf "           before trying to install mojaloop \n "
        exit 1 
    fi
    printf "    [ ok ] \n"
}

function print_end_message { 
    printf "\n\n*********************** << success >> *******************************************\n"
    printf "            -- mini-loop kubernetes install utility -- \n"
    printf "  utilities for deploying kubernetes in preparation for Mojaloop deployment   \n"
 
    printf "************************** << end  >> *******************************************\n\n"

   
    # printf "\n\n****************************************************************************************\n"
    # printf " Mojaloop.io mini-loop kubernetes installer end        \n"
    # printf "****************************************************************************************\n" 
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
echo  "USAGE: $0 -m [mode] -u [user] -v [k8 version] [-k distro]
Example 1 : k8s-install-current.sh -m install -u ubuntu -v 1.22 # install k8s k3s version 1.22
Example 2 : k8s-install-current.sh -m delete -u ubuntu -v 1.24 # delete  k8s microk8s version 1.20
Example 3 : k8s-install-current.sh -m install -k microk8s -u ubuntu -v 1.24 # install k8s microk8s distro version 1.24


Options:
-m mode ............... install|delete (-m is required)
-k kubernetes distro... microk8s|k3s (default=k3s as it installs across multiple linux distros)
-v k8s version ........ 1.22|1.23|1.24 i.e. current k8s release
-u user ............... non root user to run helm and k8s commands and to own mojaloop deployment
-h|H .................. display this message
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

DEFAULT_K8S_DISTRO="k3s"   # default to microk8s as this is what is in the mojaloop linux deploy docs.
K8S_VERSION="" 

HELM_VERSION="3.9.0"
OS_VERSIONS_LIST=(16 18 20 )
K8S_CURRENT_RELEASE_LIST=( "1.22" "1.23" "1.24" )
CURRENT_RELEASE="false"
k8s_user_home=""
k8s_arch=`uname -p`  # what arch

UBUNTU_OK_VERSIONS_LIST=(16 18 20 )
FEDORA_OK_VERSIONS_LIST=( 36 )
REDHAT_OK_VERSIONS_LIST=( 8 )

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
while getopts "m:k:v:u:hH" OPTION ; do
   case "${OPTION}" in
        m)	    mode="${OPTARG}"
        ;;
        k)      k8s_distro="${OPTARG}"
        ;;
        v)	    k8s_user_version="${OPTARG}"
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

printf "\n\n*********************************************************************************\n"
printf "            -- mini-loop kubernetes install utility -- \n"
printf "  utilities for deploying kubernetes in preparation for Mojaloop deployment \n"
printf "************************* << start >> *******************************************\n\n"

check_arch_ok 
if [[ "$mode" == "install" ]]  ; then
    verify_user
    set_k8s_distro
    set_k8s_version
    k8s_already_installed
    check_pi  # note microk8s on my pi still has some issues around cgroups 
    check_os_ok # todo add check to this once tested across other OS's more fully 
    install_prerequisites 
    add_hosts
    if [[ "$k8s_distro" == "microk8s" ]]; then 
        do_microk8s_install
    else 
        do_k3s_install
    fi 
    install_k8s_tools
    add_helm_repos 
    configure_k8s_user_env
    check_k8s_installed
    printf "==> kubernetes distro:[%s] version:[%s] is now configured for user [%s] and ready for mojaloop deployment \n" \
                "$k8s_distro" "$K8S_VERSION" "$k8s_user"
    printf "    To deploy mojaloop, please su - %s from root or login as user [%s] and then \n"  "$k8s_user" "$k8s_user"
    printf "    please execute %s/miniloop-local-install.sh\n" "$SCRIPTS_DIR"
    print_end_message 
elif [[ "$mode" == "delete" ]]  ; then
    delete_k8s 
    print_end_message 
else 
    showUsage
fi 



