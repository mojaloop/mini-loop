#!/usr/bin/env bash
# k8s-install.sh 
# install kubernetes distro microk8s or k3s, setup helm and all of the infrastructure ready for mojaloop installation
# Note: currently prepares for ML version 13.1.x 

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

function ensure_only_one_k8s_distro_installed { 
    # it seems ok to re-install microk8s over existing microk8s install or similarly to install k3s 
    # when k3s is already install but need to avoid installing k3s when k8s is already installed or vice-versa
    # check to ensure k3s isn't already installed when installing microk8s 
    if [[ -f "/usr/local/bin/k3s" && $k8s_distro == "microk8s" ]]; then 
        printf "** Error , k3s is already installed on this machine , please delete before installing microk8s **\n"
        exit 1
    fi 
    #check to ensure microk8s isn't already installed when installing k3s
    if [[ -f "/snap/bin/microk8s" && $k8s_distro == "k3s" ]]; then 
        printf "** Error , microk8s is already installed on this machine , please delete before installing k3s **\n"
        exit 1
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
        if [[ $k8s_distro == "k3s" ]]; then 
            printf " [?] \n"
            printf "** Warning : k3s & Mojaloop not tested on this operating system and/or version \n" 
            printf "             but it should work ok **\n"
        else
            printf "** Error : This operating system combination and/or version seems to be untested with mini-loop ** \n" 
            printf "   Tested os types and versions are ... \n" 
            print_ok_oses
            exit 1
        fi
    else
        printf "     os and version check  [ok] \n"
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
    if [[ -z "$k8s_distro" ]]; then  
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
    
    # if the users wants k8s v1.22 or beyond then the version is the same for either distro
    # as we will do a local helm deploy after doing local mods to the charts to enable them to run.
    current_release=false 
    if [ ! -z ${k8s_user_version+x} ] ; then
        # strip off any leading characters
        k8s_user_version=`echo $k8s_user_version |  tr -d A-Z | tr -d a-z `
        for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
            if  [[ "$k8s_user_version" == "$i" ]]; then
                current_release=true
                break
            fi  
        done
        echo "CURRENT_REL = $current_release "
        if [[ $current_release == "true" ]]; then     
            K8S_VERSION=$k8s_user_version
        else 
            printf "** Error: The specified kubernetes release [ %s ] is not a current release \n" "$k8s_user_version"
            printf "          when using the -v flag you must specify a current supported release \n"
            print_current_k8s_releases 
            printf "          alternatively simply omit the -v flag and mini-loop will default to a working older release\n"
            printf "** \n"
            exit 1 
        fi 
    else 
        if [[ $k8s_distro == "k3s" ]]; then 
            K8S_VERSION="v1.21"
        fi

        if [[ $k8s_distro == "microk8s" ]]; then 
            K8S_VERSION="1.20"
        fi
    fi 
    printf "==> kubernetes version to install set to [%s] \n" "$K8S_VERSION"

    # printf "========================================================================================\n"
    # printf "Mojaloop k8s install : set k8s version to install (default and minimum is 1.21) \n"
    # printf "========================================================================================\n\n"
    # if [[ "$k8s_user_version" == "1.21" && $k8s_distro == "k3s" ]]  ; then
    #         printf  " k8s version set correctly to : %s\n" $k8s_user_version
    # else 
    #         printf "Note -v flag not specified or invalid  => k8s version will use default:  %s \n" $DEFAULT_K8S_VERSION
    #         k8s_user_version=$DEFAULT_K8S_VERSION
    # fi
}

function do_microk8s_install {
    # TODO : Microk8s can complain that This is insecure. Location: /var/snap/microk8s/2952/credentials/client.config
    printf "================================================================================================\n"
    printf "Mojaloop microk8s install : Installing Kubernetes MicroK8s & enabling tools (helm,ingress  etc) \n"
    printf "=================================================================================================\n"

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
    K8S_VERSION=`echo v$K8S_VERSION`
    if [[ $K8S_VERSION == "v1.21" ]]; then 
        printf "=> k3s k8s versions before 1.22 need docker so installing and configuring docker\n"
        if [[ ! -f "/usr/bin/docker" ]]; then 
            curl https://releases.rancher.com/install-docker/19.03.sh | sh
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
            sh /tmp/get-docker.sh

            # set the docker cgroups to cgroupfs as k3s can't use cgroups=systemd 
            # and on Fedora docker uses cgroups=systemd on install
            if [[ $LINUX_OS == "Fedora" ]]; then
                rm -rf /etc/docker  
                mkdir /etc/docker
                echo "{" >> /etc/docker/daemon.json
                echo "    \"exec-opts\": [\"native.cgroupdriver=cgroupfs\"]" >> /etc/docker/daemon.json
                echo "}" >> /etc/docker/daemon.json
            fi 
        fi 
        printf "=> creating docker group, adding user and restarting docker \n"
        groupadd docker > /dev/null 2>&1
        usermod -a -G docker $k8s_user > /dev/null 2>&1
        systemctl restart docker > /dev/null 2>&1

        # install k3s with docker 
        printf "=> installing k3s using  docker\n"
        echo $K8S_VERSION
        curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                               INSTALL_K3S_CHANNEL=$K8S_VERSION \
                               INSTALL_K3S_EXEC=" --no-deploy traefik --docker " sh 
    else
        printf "=> k3s k8s versions from 1.22 don't use docker so it wont be installed \n"    
        printf "=> installing k3s \n"
        echo $K8S_VERSION
        curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                               INSTALL_K3S_CHANNEL=$K8S_VERSION \
                               INSTALL_K3S_EXEC=" --no-deploy traefik " sh 
    fi
    
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
    
    #install nginx => but beware which one  
    # for k8s = 1.22 need kubernetes ingress 1.0.4 or later and => chart version 4.0.6 or later 
    # for k8s < v1.22 need kubernetes nginx ingress 0.47.0 
    # see: https://kubernetes.io/blog/2021/07/26/update-with-ingress-nginx/
    # see also https://kubernetes.github.io/ingress-nginx/
    # use helm search repo -l nginx to find the chart version that corresponds to ingress release 0.47.x
    # also we wait for 600secs here to ensure nginx controller is up
    # repo is --repo https://kubernetes.github.io/ingress-nginx
    if [[ $K8S_VERSION == "1.21" ]]; then 
        ingress_chart_ver="3.33.0"
        printf "==> installing ingress chart version [%s] and wait for it to be ready\n" "$ingress_chart_ver"
        su - $k8s_user -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx --version=$ingress_chart_version --repo https://kubernetes.github.io/ingress-nginx" 
    else 
        #printf "==> installing ingress chart version [%s] and wait for it to be ready\n" "$ingress_chart_ver"
        su - $k8s_user -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx" 
    fi 
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
    grep "start of config added by mini-loop" $k8s_user_home/.bashrc 
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
        if [[ -z "$k8s_user" ]]; then 
            printf "** Error: The operating system user has not been specified with the -u flag \n" 
            printf "          the user specified with the -u flag must exist and not be the root user \n" 
            printf "** \n"
            exit 1
        fi

        if [[ `id -u $k8s_user` == 0 ]]; then 
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
        printf "==>Removing any existing Microk8s installation "
        snap remove microk8s > /dev/null 2>&1
        if [[ $? -eq 0  ]]; then 
            printf " [ ok ] \n"
        else 
            printf " [ microk8s delete failed ] \n"
            printf "** was microk8s installed ?? \n" 
            printf "   if so please try running \"snap remove microk8s\" manually ** \n"
        fi
    else 
        printf "==>Removing any existing k3s installation and helm binary"
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
    printf "\n\n****************************************************************************************\n"
    printf " Mojaloop.io mini-loop kubernetes installer end        \n"
    printf "****************************************************************************************\n" 
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
Example 1 : k8s-install.sh -m install -u ubuntu -v 1.20 # install k8s microk8s version 1.20
Example 2 : k8s-install.sh -m delete -u ubuntu -v 1.20 # delete  k8s microk8s version 1.20
Example 3 : k8s-install.sh -m install -k k3s -u ubuntu -v 1.24 # install k8s k3s distro version 1.24


Options:
-m mode ............... install|delete (-m is required)
-k kubernetes distro... microk8s|k3s (default is microk8s)
-v k8s version ........ must specify a currently supported kubernetes release (or omit this flag for defaults)
-u user ............... non root user to run helm and k8s commands and to own mojaloop (default : mojaloop) 
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

DEFAULT_K8S_DISTRO="microk8s"   # default to microk8s as this is what is in the mojaloop linux deploy docs.
K8S_VERSION="" 

HELM_VERSION="3.9.0"
OS_VERSIONS_LIST=(16 18 20 )
K8S_CURRENT_RELEASE_LIST=( "1.22" "1.23" "1.24" )
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

printf "\n\n****************************************************************************************\n"
printf " Mojaloop.io mini-loop kubernetes installer start        \n"
printf "****************************************************************************************\n\n"



check_arch_ok 
if [[ "$mode" == "install" ]]  ; then
    # set the user to run k8s commands
    if [ -z ${k8s_user+x} ] ; then
            k8s_user=$DEFAULT_K8S_USER
    fi
    
    ensure_only_one_k8s_distro_installed
    check_pi  # note microk8s on my pi still has some issues around cgroups 
    ## when I have k3s going => only need to check OS if using microk8s !
    #if [[ "$k8s_distro" == "microk8s" ]]; then 
    #check_os_ok # check this is an ubuntu OS v18.04 or later 
    #fi 
    verify_user 
    install_prerequisites 
    set_k8s_distro
    set_k8s_version
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
    printf "==> The kubernetes environment is now configured for user [%s] and ready for mojaloop deployment \n" "$k8s_user"
    printf "    To deploy mojaloop, please su - %s from root  or login as user [%s] and then \n"  "$k8s_user" "$k8s_user"
    printf "    execute the %s/01_install_miniloop.sh script \n\n"  "$SCRIPTS_DIR"   

    print_end_message 
elif [[ "$mode" == "delete" ]]  ; then
    delete_k8s 
    print_end_message 
else 
    showUsage
fi 



