#!/usr/bin/env bash
# k3d test of calico network policy

kubectl run web --image nginx --labels app=web --expose --port 80
kubectl run test --image alpine -- sleep 3600


cat <<EOF | kubectl apply -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-deny-all
spec:
  podSelector:
    matchLabels:
      app: web
  ingress: []
EOF
