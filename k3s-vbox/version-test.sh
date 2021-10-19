#!/usr/bin/env bash
# test application running in multiple versions of kubernetes 
##
# Bash Niceties
##

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
#trap ' echo "\"${last_command}\" command filed with exit code $?."' EXIT

# exit on unset vars
set -u

function install_v14poc {
  printf "========================================================================================\n"
  printf "installing mojaloop v14 PoC \n"
  printf "\n"
  printf "========================================================================================\n"
  # install the chart
        echo "install backend services <$BACKEND_NAME> helm chart and wait for upto $BE_TIMEOUT_SECS secs for it to be ready"
        start_timer=$(date +%s)
        su - vagrant -c "helm install --wait --timeout $BE_TIMEOUT_SECS $BACKEND_NAME $MOJALOOP_WORKING_DIR/dependencies/backend"
        end_timer=$(date +%s)
        elapsed_secs=$(echo "$end_timer - $start_timer" | bc )
        if [[ `helm status $BACKEND_NAME | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
                echo "helm release <$BACKEND_NAME> deployed sucessfully after <$elapsed_secs> secs "
        else 
                echo "Error: $BACKEND_NAME helm chart  deployment failed "
                exit 1
        fi 


        echo "install v14 PoC services <$RELEASE_NAME> helm chart and wait for upto $ML_TIMEOUT_SECS secs for it to be ready"
        start_timer=$(date +%s)
        su - vagrant -c "helm install --wait --timeout $ML_TIMEOUT_SECS $RELEASE_NAME $MOJALOOP_WORKING_DIR/mojaloop/mojaloop"        
        end_timer=$(date +%s)
        elapsed_secs=$(echo "$end_timer - $start_timer" | bc )
        if [[ `helm status $RELEASE_NAME | grep "^STATUS:" | awk '{ print $2 }' ` = "deployed" ]] ; then 
                echo "helm release <$RELEASE_NAME> deployed sucessfully after <$elapsed_secs> secs "
        else 
                echo "Error: $RELEASE_NAME helm chart  deployment failed "
                exit 1
        fi 

        
}

function post_install_health_checks {
        echo "check the endpoints to verify deployment" 
        if [[ `curl -s http://admin-api-svc.local/health | \
            perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
                echo "admin-api-svc endpoint healthcheck failed"
                exit 1 
        fi

        if [[ `curl -s http://transfer-api-svc.local/health | \
            perl -nle '$count++ while /OK+/g; END {print $count}' ` -lt 2 ]] ; then
                echo "transfer-api-svc endpoint healthcheck failed"
                exit 1 
        fi
        echo "$RELEASE_NAME configuration of mojaloop deployed ok and passes endpoint health checks"
}

################################################################################
# MAIN
################################################################################

##
# Environment Config
##
MOJALOOP_WORKING_DIR=/vagrant/charts
BACKEND_NAME="be" 
RELEASE_NAME="ml"
BE_TIMEOUT_SECS="600s"
ML_TIMEOUT_SECS="600s"
export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

chown root /etc/rancher/k3s/k3s.yaml
chmod 600 /etc/rancher/k3s/k3s.yaml

install_v14poc
post_install_health_checks

echo " ok "
exit

#k8s_versions=("v1.20" "v1.21"  "v1.22")
k8s_versions=("v1.22")
nginx_version=""

echo $k8s_versions 

for i in ${k8s_versions[@]}; do
        echo "k8s_versions{$i}"
        /usr/local/bin/k3s-uninstall.sh 
        #su - vagrant -c "helm delete ingress-nginx "     
        curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                                INSTALL_K3S_CHANNEL=$i \
                                INSTALL_K3S_EXEC=" --no-deploy traefik " sh  
        
        cp /etc/rancher/k3s/k3s.yaml /home/vagrant/k3s.yaml
        chown vagrant /home/vagrant/k3s.yaml
        chmod 600 /home/vagrant/k3s.yaml   
        export KUBECONFIG=/home/vagrant/k3s.yaml  
        sleep 30             
        su - vagrant -c "kubectl get nodes "  
        
        if [[ $i == "v1.22" ]] ; then
                nginx_version="4.0.6"
        else 
                nginx_version="3.33.0"     
        fi
        echo "installing nginx-ingress version : $nginx_version"
        su - vagrant -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx/ingress-nginx --version=$nginx_version  "
        su - vagrant -c "kubectl get pods --all-namespaces "

        # assuming this is ok so far => now install the v14.0 ML helm charts
        # should check that the repo exists at this point and clone it if not existing.
        install_v14poc
        post_install_health_checks


done
