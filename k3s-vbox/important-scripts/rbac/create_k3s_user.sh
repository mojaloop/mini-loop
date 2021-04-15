#!/usr/bin/env bash
# create a new user for the k3s cluster to enable testing of 
# PSP, RBAC , calico etc
# see : https://betterprogramming.pub/k8s-tips-give-access-to-your-clusterwith-a-client-certificate-dfb3b71a76fe
# also : https://docs.bitnami.com/tutorials/configure-rbac-in-your-kubernetes-cluster/#use-case-1-create-user-with-limited-namespace-access



RUN_DIR=$( cd $(dirname "$0") ; pwd )
echo "RUN_DIR : $RUN_DIR"
export USER=user1
export USERDIR=$RUN_DIR/k3s_$USER
echo "creating new user kubeconfig file in $USERDIR"
mkdir $USERDIR

echo ">> generate an RSA key" 
openssl genrsa -out $USERDIR/$USER.key 4096


# create the template Certificate Signing Request config 
# with our new user 
cat << !EOF > $USERDIR/csr.cnf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = ${USER}
O = dev

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
!EOF

echo ">> create the $USER CSR : run openssl " 
openssl req -config $USERDIR/csr.cnf -new -key $USERDIR/$USER.key -nodes -out $USERDIR/$USER.csr


# create the k8s rsource definition for creating csr
export BASE64_CSR=`cat $USERDIR/$USER.csr | base64 | tr -d '\n'`
echo ">>> BASE64_CSR = $BASE64_CSR "

cat << !EOF > $USERDIR/csr.yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: mycsr
spec:
  groups:
  - system:authenticated
  request: ${BASE64_CSR}
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
!EOF

echo "clear any old csr for this user"
kubectl delete csr mycsr
#  if [ $? -ne 0 ]; then
#     printf  "clean up of exisrting csr failed please remove manually "
#     kubectl get csr 
#     exit $?
#   fi

echo ">>> create the CSR in k8s : kubectl "
cat $USERDIR/csr.yaml | kubectl apply -f -

# check the csr and approve it 
kubectl get csr
kubectl certificate approve mycsr
kubectl get csr

echo "create $USERDIR/$USER.crt to check what got produced "
kubectl get csr mycsr -o jsonpath='{.status.certificate}' | base64 --decode \
     > $USERDIR/$USER.crt

echo "decoding that yeilds " 
openssl x509 -in $USERDIR/$USER.crt -noout -text


# now we need to build a kubeconfig for the user 
# User identifier
# export USER="$USER"
# Cluster Name (get it from the current context)
export CLUSTER_NAME=$(kubectl config view --minify -o jsonpath={.current-context})
echo "CLUSTER_NAME=$CLUSTER_NAME"
# Client certificate
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr mycsr -o jsonpath='{.status.certificate}')
echo "CLIENT_CERTIFICATE_DATA = $CLIENT_CERTIFICATE_DATA"
# Cluster Certificate Authority
export CLUSTER_CA=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority-data"')
echo "CLUSTER_CA = $CLUSTER_CA"
# API Server endpoint
export CLUSTER_ENDPOINT=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."server"')

echo "Creating kubeconfig for USER $USER"
cat << !EOF > $USERDIR/kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_ENDPOINT}
  name: ${CLUSTER_NAME}
users:
- name: ${USER}
  user:
    client-certificate-data: ${CLIENT_CERTIFICATE_DATA}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USER}
  name: ${USER}-${CLUSTER_NAME}
current-context: ${USER}-${CLUSTER_NAME}
!EOF

export KUBECONFIG=$USERDIR/kubeconfig
kubectl config view 

kubectl config set-credentials $USER \
  --client-key=$USERDIR/$USER.key \
  --embed-certs=true


#kubectl config set-credentials fred --client-certificate=fred.crt  --client-key=./fred.key
#kubectl config set-context --current --cluster=default --namespace=default --user=fred

echo "try running k get nodes witht he new user "
echo "this should fail with no privs "

kubectl get nodes 
