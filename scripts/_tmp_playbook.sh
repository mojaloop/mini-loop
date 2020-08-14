

curl -sfL https://get.k3s.io | sh -
# TODO: wait for node somehow

# Change file permissions to normal users can call `kubectl ...`
sudo chmod 644 /etc/rancher/k3s/k3s.yaml


curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

npm install -g newman


PATH_TO_HELM_REPO=""
MOJALOOP_WORKING_DIR=/tmp
MOJALOOP_CHARTS_DIR=${MOJALOOP_WORKING_DIR}/helm
MOJALOOP_REPO_DIR=${MOJALOOP_CHARTS_DIR}/repo
MOJALOOP_CHARTS_BRANCH='fix/219-kubernetes-17-helm2-2'
RELEASE_NAME="mini-loop"
TIMEOUT_SECS="2400s"
POSTMAN_TAG="v10.1.0"
POSTMAN_COLLECTION_DIR=${MOJALOOP_WORKING_DIR}/postman
POSTMAN_ENV_FILE=${POSTMAN_COLLECTION_DIR}/environments/Mojaloop-Local.postman_environment.json
POSTMAN_COLLECTION_NAME=OSS-New-Deployment-FSP-Setup.postman_collection.json
PATH_TO_KUBECTL_CONFIG=/etc/rancher/k3s/k3s.yaml
export KUBECONFIG=${PATH_TO_KUBECTL_CONFIG}


git clone --branch ${MOJALOOP_CHARTS_BRANCH} https://github.com/vessels-tech/helm.git ${MOJALOOP_CHARTS_DIR}
cd ${MOJALOOP_CHARTS_DIR}
./package.sh
cd ${MOJALOOP_REPO_DIR}

helm delete $RELEASE_NAME > /dev/null 2>&1

pyenv global 3.7.0
python3 -m http.server & 


helm repo add mojaloop http://mojaloop.io/helm/repo/
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm repo add kiwigrid https://kiwigrid.github.io
helm repo add elastic https://helm.elastic.co
helm repo update

helm repo list


helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  http://localhost:8000/mojaloop-10.1.0.tgz 
