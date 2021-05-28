#!/usr/bin/env bash
# test mysql db connection
kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql -- mysql -h mysql-als -u account_lookup -ppassword account_lookup -e 
