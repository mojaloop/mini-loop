#!/usr/bin/env bash
# copy an image from local docker to local containerd (cri) 
# this is mainly for microk8s right now 

DOCKER_IMAGE=central_ledger_local:latest
#CONTAINERD_IMAGE=central_ledger_local

docker save $DOCKER_IMAGE > /tmp/dockertemp.tar
microk8s ctr image import /tmp/dockertemp.tar

microk8s ctr image ls | grep -i $DOCKER_IMAGE

