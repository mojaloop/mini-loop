#!/usr/bin/env bash
helm delete db
sleep 2
kubectl get pvc | cut -d " " -f1 | xargs kubectl delete pvc
kubectl get pv | cut -d " " -f1 | xargs kubectl delete pv
kubectl get pv