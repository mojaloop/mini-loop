
#!/usr/bin/env bash
# run tests 

cat ~/work/centralledger/chart-service/templates/config/default.json
helm delete cs > /dev/null 2>&1 
helm delete tp >  /dev/null 2>&1 

# cd  ~/work/centralledger/chart-service
# helm dependency build 
# cd 
# printf "\ninstalling centralledger chart-admin\n"
# printf "===========================================\n"

# helm install cs ./work/centralledger/chart-service

## centralledger
helm delete cl > /dev/null 2>&1
cd  ~/work/centralledger
helm dependency build 
cd
printf "\ninstalling centralledger \n"
printf "===========================================\n"
helm install cl ./work/centralledger

## account-lookup-service
helm delete als > /dev/null 2>&1 
sleep 1 
cd  ~/work/account-lookup-service
helm dependency build 
cd
printf "\ninstalling account-lookup-service \n"
printf "===========================================\n"
helm install als ./work/account-lookup-service

helm install cs ./work/thirdparty
cd  ~/work/thirdparty
rm Chart.lock
helm dependency build 
cd
printf "\ninstalling 3ppi \n"
printf "===========================================\n"
helm install tp  ./work/thirdparty

kubectl get pods 

