#!/usr/bin/env bash

export NAMESPACE="default" 

# dump the data from a mongo database running in kubernetes and copy the archive to 
# /tmp

  mongopod=`kubectl get pods --namespace $NAMESPACE | grep -i mongodb |awk '{print $1}'` 
  printf "==> dumping mongodb data from pod %s   \n" $mongopod
  mongo_root_pw=`kubectl get secret mongodb -o jsonpath='{.data.mongodb-root-password}'| base64 -d` 
  kubectl exec --stdin --tty $mongopod -- mongodump  -u root -p $mongo_root_pw \
               --gzip --archive=/tmp/mongodata.gz
  kubectl cp $mongopod:/tmp/mongodata.gz /tmp/mongodata.gz # copy dmongo dump archove to /tmp
