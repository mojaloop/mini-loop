
#!/usr/bin/env bash
# run tests 

cat ~/work/centralledger/chart-service/templates/config/default.json
helm delete cs > /dev/null 2>&1 
helm delete als > /dev/null 2>&1 
cd  ~/work/centralledger/chart-service
helm dependency build 
cd 
printf "\ninstalling centralledger chart-admin\n"
printf "===========================================\n"

helm install cs ./work/centralledger/chart-service
cd  ~/work/account-lookup-service
helm dependency build 
cd
printf "\ninstalling account-lookup-service \n"
printf "===========================================\n"
helm install als ./work/account-lookup-service

kubectl get pods 

