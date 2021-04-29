#!/usr/bin/env bash
# see: https://docs.projectcalico.org/getting-started/kubernetes/k3s/quickstart
#      https://docs.projectcalico.org/security/tutorials/kubernetes-policy-demo/kubernetes-demo


kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml

echo "watch kubectl get pods --all-namespaces"

