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
    # check this is ubuntu OS and a recent version => all ok ; else warn user it is not well tested
    ok=false
    # make sure the utility to check the operating system type and version exists
    if [ -x "/usr/bin/lsb_release" ]; then
        # now check that this os is Ubuntu (for now this is all that is tested)
        os=`lsb_release --d | perl -ne 'print  if s/^.*Ubuntu.*(\d+).(\d+).*$/Ubuntu/' `
        if [[ $os == "Ubuntu" ]] ; then 
            printf "Identified operating system as %s [ok] \n" $os   
            # now check that the Ubuntu version is reasonably recent 
            ver=`/usr/bin/lsb_release --d | perl -ne 'print $&  if m/(\d+)/' `
            for i in "${OS_VERSIONS_LIST[@]}"; do
                if  [[ "$ver" == "$i" ]]; then
                     ok=true
                     printf "Identified operating system release as %s [ok] \n" "$i" 
                     break
                fi  
            done
        fi
    fi

    if [[ "$ok" == "false" ]]; then 
        printf "** Error:  either the operating system is not Ubuntu or \n" "$ok"
        printf "   it is older than version 16 of Ubuntu or newer than version 20 \n" "$ok"
        printf "   Currently this script is only well tested against versions of Ubuntu 16 to 20  ** \n "
        printf "* Note: if you are confident you could proceed by editing this script and commenting out the check_os_ok test \n"
        printf "   and then re-run but I have not tested it outside of recent Ubuntu releases * \n"
        exit 1
    fi 
}




function install_prerequisites {
    printf "==> Install prerequisites: run update ...\n"
    apt update

    printf "==> Install prerequisites: installing snapd ...\n"
    apt install snapd -y 

    printf "==> Install prerequisites: installing python and python libs ...\n"
    apt install python3-pip -y 
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

function set_k8_version {
    printf "========================================================================================\n"
    printf "Mojaloop k8s install : set k8s version to install (default and minimum is 1.21) \n"
    printf "========================================================================================\n\n"
    if [[ "$k8s_version" == "1.21" ]]  ; then
            printf  " k8s version set correctly to : %s\n" $k8s_version
    else 
            printf "Note -v flag not specified or invalid  => k8s version will use default:  %s \n" $DEFAULT_K8S_VERSION
            k8s_version=$DEFAULT_K8S_VERSION
    fi
}


function do_microk8s_install {
    # TODO : Microk8s can complain that This is insecure. Location: /var/snap/microk8s/2952/credentials/client.config
    printf "========================================================================================\n"
    printf "Mojaloop microk8s install : Installing Kubernetes MicroK8s engine and tools (helm etc) \n"
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

function do_k3s_install {
    printf "========================================================================================\n"
    printf "Mojaloop k3s install : Installing Kubernetes k3s engine and tools (helm/ingress etc) \n"
    printf "========================================================================================\n"

    # # first do docker (this can go once the percona chart issue is resolved )
    # if [[ ! -f "/usr/bin/docker" ]]; then 
    #     curl https://releases.rancher.com/install-docker/19.03.sh | sh
    # fi 
    # printf "=> creating docker group, adding user and restarting docker \n"
    # groupadd docker > /dev/null 2>&1
    # usermod -a -G docker $k8s_user > /dev/null 2>&1
    # systemctl restart docker > /dev/null 2>&1

    # # install k3s with docker 
    # printf "=> installing k3s using  docker\n"
    # curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
    #                            INSTALL_K3S_CHANNEL=$K8S_VERSION \
    #                            INSTALL_K3S_EXEC=" --no-deploy traefik --docker " sh 

    # export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    # cp /etc/rancher/k3s/k3s.yaml  $k8s_user_home/k3s.yaml
    # chown $k8s_user  $k8s_user_home/k3s.yaml
    # chmod 600  $k8s_user_home/k3s.yaml 
    # echo "source .bashrc" >>   $k8s_user_home/.bash_profile 
    # echo "export KUBECONFIG=\$HOME/k3s.yaml" >>  $k8s_user_home/.bashrc
    # echo "export KUBECONFIG=\$HOME/k3s.yaml" >>   $k8s_user_home/.bash_profile  

    # install helm
    printf "==> installing helm " 
    helm_arch_str=""
    if [[ "$k8s_arch" == "x86_64" ]]; then 
        helm_arch_str="amd64"
    else 
        printf "** Error need to implement arm architecture install for helm ** \n"
        exit 1
    fi
    cd /tmp
    curl -L -s -o ./helm.tar.gz https://get.helm.sh/helm-v$HELM_VERSION-linux-$helm_arch_str.tar.gz
    exit
    cat ./helm.tar.gz | gzip -d -c | tar xf -
    mv ./linux-amd64/helm /usr/local/bin  
    /usr/local/bin/helm version > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then 
        printf "[ok]\n"
    else 
        printf "** Error : helm install seems to have failed ** \n"
        exit 1
    fi
    
    #install nginx => but beware which one  
    # for k8s = 1.22 need kubernetes ingress 1.0.4 => chart version 4.0.6
    # for k8s < v1.22 need kubernetes nginx ingress 0.47.0 
    # see: https://kubernetes.io/blog/2021/07/26/update-with-ingress-nginx/
    # see also https://kubernetes.github.io/ingress-nginx/
    # use helm search repo -l nginx to find the chart version that corresponds to ingress release 0.47.x
    # also we wait for 600secs here to ensure nginx controller is up
    ingress_chart_ver="3.33.0"
    printf "==> installing ingress chart version [%s] and wait for it to be ready" "$ingress_chart_ver"
    su - $k8s_user -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx/ingress-nginx --version=$ingress_chart_version "

    # TODO : check to ensure that the ingress is indeed running 
}

function install_k8s_tools { 
    printf "==> install kubernetes tools, kubens, kubectx kustomize \n" 
    curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubens_v0.9.4_linux_x86_64.tar.gz | gzip -d -c | tar xf -
    mv ./kubens /usr/local/bin
    curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx_v0.9.4_linux_x86_64.tar.gz | gzip -d -c | tar xf -
    mv ./kubectx /usr/local/bin

    # install kustomize
    curl -s "https://raw.githubusercontent.com/\
    kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
    mv ./kustomize /usr/local/bin
}

function add_helm_repos { 
    printf "==> add the helm repos required to install and run Mojaloop version 13.x \n" 
    su - $k8s_user -c "helm repo add kiwigrid https://kiwigrid.github.io"
    su - $k8s_user -c "helm repo add elastic https://helm.elastic.co"
    su - $k8s_user -c "helm repo add bitnami https://charts.bitnami.com/bitnami"
    su - $k8s_user -c "helm repo update"
}

function configure_k8s_user_env { 
    # TODO : this is pretty ugly as if it is re-run it appends multiple times to the .bashrc => fix that up
    # TODO : this assumes user is using bash shell 
    # printf "==> configure kubernetes environment for user [%s] by adding kubectl utilities to .bashrc  \n" "$k8s_user" 
    echo "source <(kubectl completion bash)" >> $k8s_user_home/.bashrc # add autocomplete permanently to your bash shell.
    echo "alias k=kubectl " >>  $k8s_user_home/.bashrc
    echo "complete -F __start_kubectl k " >>  $k8s_user_home/.bashrc
    echo "alias ksetns=\"kubectl config set-context --current --namespace\" " >>  $k8s_user_home/.bashrc
    echo "alias ksetuser=\"kubectl config set-context --current --user\" "  >>  $k8s_user_home/.bashrc   
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
Example 1 : k8s-install.sh -m install -u ubuntu -v 1.20 # install k8s microk8s version 1.20
Example 2 : k8s-install.sh -m remove -u ubuntu -v 1.20 # remove  k8s microk8s version 1.20
Example 3 : k8s-install.sh -m install -k k3s -u ubuntu -v 1.21 # install k8s k3s distro version 1.21


Options:
-m mode ............... install|remove (-m is required)
-k kubernetes distro... microk8s|k3s (default is microk8s)
-v k8s version ........ 1.20 (default : 1.20 only right now due to  https://github.com/mojaloop/project/issues/2447 )
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

# echo $BASE_DIR
# echo $RUN_DIR
# echo $SCRIPTS_DIR

DEFAULT_K8S_DISTRO="microk8s" 
DEFAULT_K8S_VERSION="1.21" # default version to test
HELM_VERSION="3.9.0"
OS_VERSIONS_LIST=(16 18 20 )
k8s_user_home=""
k8s_arch=`uname -p`  # what arch

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
    ## when I have k3s going => only need to check OS if using microk8s !
    check_os_ok # check this is an ubuntu OS v18.04 or later 
    verify_user 
    #install_prerequisites 
    set_k8s_distro
    set_k8s_version
    add_hosts
    if [[ "$k8s_distro" == "microk8s" ]]; then 
        echo "do_microk8s_install -- not really "
    else 
        do_k3s_install
    fi 
    install_k8s_tools
    add_helm_repos 
    configure_k8s_user_env
    printf "==> The kubernetes environment is now configured for user [%s] and ready for mojaloop deployment \n" "$k8s_user"
    printf "    To deploy mojaloop, please su - %s from root  or login as user [%s] and then \n"  "$k8s_user" "$k8s_user"
    printf "    execute the %s/01_install_miniloop.sh script \n"  "$SCRIPTS_DIR"    
elif [[ "$mode" == "remove" ]]  ; then
    
    if [[ "$k8s_distro" == "microk8s" ]]; then 
        printf "==>Removing any existing Microk8s installation "
        snap remove microk8s > /dev/null 2>&1
        if [[ $? -eq 0  ]]; then 
            printf " [ ok ] \n"
        else 
            printf " [ microk8s remove failed ] \n"
            printf "** was microk8s installed ?? \n" 
            printf "   if so please try running \"snap remove microk8s\" manually ** \n"
        fi
    else 
        printf "==>Removing any existing k3s installation "
        /usr/local/bin/k3s-uninstall.sh >> /dev/null 2>&1
        if [[ $? -eq 0  ]]; then 
            printf " [ ok ] \n"
        else 
            printf " [ k3s remove failed ] \n"
            printf "** was k3s installed ?? \n" 
            printf "   if so please try running \"/usr/local/bin/k3s-uninstall.sh\" manually ** \n"
        fi
        exit
    fi 
else 
    showUsage
fi 



