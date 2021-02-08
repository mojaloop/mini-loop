#!/usr/bin/env bash
# small calico demo 
# see https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/kubernetes-demo
# run this as vagrant user or other normal user

# load the demo pods and configs
kubectl create -f https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/manifests/00-namespace.yaml
kubectl create -f https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/manifests/01-management-ui.yaml
kubectl create -f https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/manifests/02-backend.yaml
kubectl create -f https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/manifests/03-frontend.yaml
kubectl create -f https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/manifests/04-client.yaml


# enable isolation
kubectl create -n stars -f https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/policies/default-deny.yaml
kubectl create -n client -f https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/policies/default-deny.yaml

