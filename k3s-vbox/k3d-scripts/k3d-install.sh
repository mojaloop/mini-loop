#!/usr/bin/env bash
# for multinode k3d/k3s vagrant / mojaloop installation 
# TLS for NGINX
# Valid certificates


#install docker.io
# apt update -y 
# apt install docker.io -y 
# groupadd docker
# usermod -a -G docker vagrant
# systemctl start docker

# install kubectl 
# cd /tmp
# curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
# oksum=`echo "$(<kubectl.sha256) kubectl" | sha256sum --check`
# if [ "$oksum" != "kubectl: OK" ] ; then
#     echo "invalid kubectl checksum ..exiting"
#     exit 1
# fi
# install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

# installing k3d (so we can have multi-node)
#su - vagrant -c "wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash" 

# create cluster with calico CNI
# see : https://en.sokube.ch/post/k3s-k3d-k8s-a-new-perfect-match-for-dev-and-test-1


#su - vagrant -c "wget -q https://raw.githubusercontent.com/rancher/k3d/main/docs/usage/guides/calico.yaml -P /home/vagrant"
# k3d cluster create calico --k3s-server-arg '--flannel-backend=none, --kube-apiserver-arg=enable-admission-plugins=NodeRestriction,PodSecurityPolicy,ServiceAccount' \
#      --volume "/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml" 

# su - vagrant -c "k3d cluster create calico --k3s-server-arg '--flannel-backend=none' --k3s-server-arg '--no-deploy=traefik' \
#       --volume \"/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml\" "

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/k3s.yaml
chown vagrant /home/vagrant/k3s.yaml
chmod 600 /home/vagrant/k3s.yaml 
echo "export KUBECONFIG=/home/vagrant/k3s.yaml" >> /home/vagrant/.bashrc
echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc # add autocomplete permanently to your bash shell.
echo "alias k=kubectl " >> /home/vagrant/.bashrc
echo "complete -F __start_kubectl k " >> /home/vagrant/.bashrc
echo 'alias ksetns="kubectl config set-context --current --namespace"'  >> /home/vagrant/.bashrc
echo "alias ksetuser=\"kubectl config set-context --current --user\""  >> /home/vagrant/.bashrc

cat << !EOF > /home/vagrant/helm-ingress-nginx.yaml 
# see https://rancher.com/docs/k3s/latest/en/helm/
# see https://github.com/kubernetes/ingress-nginx/tree/master/charts/ingress-nginx
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: ingress-controller-nginx
  namespace: kube-system
spec:
  repo: https://kubernetes.github.io/ingress-nginx
  chart: ingress-nginx
  version: 3.7.1
  targetNamespace: kube-system
!EOF
chown vagrant /home/vagrant/helm-ingress-nginx.yaml 

# # create a k3d cluster with nginx ingress and using calico CNI and networkpolicy
# su - vagrant -c "k3d cluster create moja --k3s-server-arg '--flannel-backend=none' --k3s-server-arg '--no-deploy=traefik' \
#       --agents 2 \ 
#       --volume \"/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml\" \
#       --volume \"/home/vagrant/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml\" " 

# install kustomize
curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
mv ./kustomize /usr/local/bin

# add the mojaloop endpoints per doc at 
echo "add /etc/hosts entries for local access to mojaloop endpoints" 
ENDPOINTSLIST=(127.0.0.1    localhost forensic-logging-sidecar.local central-kms.local central-event-processor.local email-notifier.local central-ledger.local 
central-settlement.local ml-api-adapter.local account-lookup-service.local 
 account-lookup-service-admin.local quoting-service.local moja-simulator.local 
 central-ledger central-settlement ml-api-adapter account-lookup-service 
 account-lookup-service-admin quoting-service simulator host.docker.internal)
export ENDPOINTS=`echo ${ENDPOINTSLIST[*]}`

perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' /etc/hosts
ping  -c 2 account-lookup-service-admin 

# install helm
echo "installing helm "
echo "ID is `id`"
cd $HOME
curl -o $HOME/helm.tar.gz https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz
cat helm.tar.gz | gzip -d -c | tar xf -
cp $HOME/linux-amd64/helm /usr/local/bin 

echo "Mojaloop: add helm repos ..." 
su - vagrant -c "helm repo add mojaloop http://mojaloop.io/helm/repo/"
su - vagrant -c "helm repo add stable https://charts.helm.sh/stable"
su - vagrant -c "helm repo add incubator https://charts.helm.sh/incubator"
su - vagrant -c "helm repo add kiwigrid https://kiwigrid.github.io"
su - vagrant -c "helm repo add elastic https://helm.elastic.co"
su - vagrant -c "helm repo add bitnami https://charts.bitnami.com/bitnami"
su - vagrant -c "helm repo add codecentric https://codecentric.github.io/helm-charts"
su - vagrant -c "helm repo add nginx-stable https://helm.nginx.com/stable"
su - vagrant -c "helm repo add kong https://charts.konghq.com" 
su - vagrant -c "helm repo update"
su - vagrant -c "export KUBECONFIG=~/k3s.yaml; helm list"
su - vagrant -c "helm repo list"