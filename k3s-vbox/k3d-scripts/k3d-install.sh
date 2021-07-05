#!/usr/bin/env bash
# for multinode k3d/k3s vagrant / mojaloop installation 
# see https://k3d.io

# various yum packages 
apt install bash-completion -y

echo "install  version 10+ of node"
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash
apt-get install -y nodejs
apt-get install -y jq

#install docker.io as k3d needs docker currently in fact it runs in containers in docker
apt update -y 
apt install docker.io -y 
groupadd docker
usermod -a -G docker vagrant
systemctl start docker

# installing k3d (so we can have multi-node)
su - vagrant -c "wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash" 

# install & configure kubectl 
cd /tmp
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
oksum=`echo "$(<kubectl.sha256) kubectl" | sha256sum --check`
if [ "$oksum" != "kubectl: OK" ] ; then
    echo "invalid kubectl checksum ..exiting"
    exit 1
fi
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc # add autocomplete permanently to your bash shell.
echo "alias k=kubectl " >> /home/vagrant/.bashrc
echo "complete -F __start_kubectl k " >> /home/vagrant/.bashrc
echo 'alias ksetns="kubectl config set-context --current --namespace"'  >> /home/vagrant/.bashrc
echo "alias ksetuser=\"kubectl config set-context --current --user\""  >> /home/vagrant/.bashrc

# install kustomize
curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
mv ./kustomize /usr/local/bin

# install helm
echo "installing helm "
echo "ID is `id`"
cd $HOME
curl -o $HOME/helm.tar.gz https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz
cat helm.tar.gz | gzip -d -c | tar xf -
cp $HOME/linux-amd64/helm /usr/local/bin 

# create k3d cluster with calico CNI and nginx ingress
# see : https://en.sokube.ch/post/k3s-k3d-k8s-a-new-perfect-match-for-dev-and-test-1
su - vagrant -c "wget -q https://raw.githubusercontent.com/rancher/k3d/main/docs/usage/guides/calico.yaml -P /home/vagrant"
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
su - vagrant -c "k3d cluster create mojaclus --port 8080:80@loadbalancer --port 8443:443@loadbalancer --k3s-server-arg '--flannel-backend=none' --k3s-server-arg '--no-deploy=traefik' \
      --agents 2 \ 
      --volume \"/home/vagrant/calico.yaml:/var/lib/rancher/k3s/server/manifests/calico.yaml\" \
      --volume \"/home/vagrant/helm-ingress-nginx.yaml:/var/lib/rancher/k3s/server/manifests/helm-ingress-nginx.yaml\" " 

su - vagrant -c "k3d kubeconfig get mojaclus > /home/vagrant/mojaconfig.yaml"
echo "export KUBECONFIG=/home/vagrant/mojaconfig.yaml" >> /home/vagrant/.bashrc

#npx ml-bootstrap@0.3.16 -c $DIR/../docker-local/ml-bootstrap-config.json5