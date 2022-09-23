
#!/usr/bin/env bash
# run tests 
WORK_DIR="$HOME/work"

declare -a charts=(
        eventstreamprocessor
        simulator
        monitoring/promfana
        monitoring/efk
        account-lookup-service
        als-oracle-pathfinder
        centralkms
        forensicloggingsidecar
        centralledger
        centralenduserregistry
        centralsettlement
        emailnotifier
        centraleventprocessor
        central
        ml-api-adapter
        quoting-service
        finance-portal
        finance-portal-settlement-management
        transaction-requests-service
        bulk-centralledger/
        bulk-api-adapter/
        mojaloop-bulk/
        mojaloop-simulator
        ml-testing-toolkit
        ml-testing-toolkit-cli
        thirdparty/chart-auth-svc
        thirdparty/chart-consent-oracle
        thirdparty/chart-tp-api-svc
        thirdparty
        mojaloop
        kube-system/ntpd/
        ml-operator
    )


for chart in "${charts[@]}"
do

    helm delete "$chart" > /dev/null 2>&1 
    printf "\ninstalling %s \n" $chart
    printf "===========================================\n"
    helm install $chart $WORK_DIR/$chart
done 

# cd  ~/work/centralledger/chart-service
# helm dependency build 
# cd 
# printf "\ninstalling centralledger chart-admin\n"
# printf "===========================================\n"

# helm install cs ./work/centralledger/chart-service

## centralledger
# printf "\ninstalling centralledger \n"
# printf "===========================================\n"
# helm delete cl > /dev/null 2>&1
# cd  ~/work/centralledger
# helm dependency build > /dev/null 2>&1
# cd
# helm install cl ./work/centralledger

# ## account-lookup-service
# printf "\ninstalling account-lookup-service \n"
# printf "===========================================\n"
# helm delete als > /dev/null 2>&1 
# sleep 1 
# cd  ~/work/account-lookup-service
# helm dependency build > /dev/null 2>&1
# cd
# helm install als ./work/account-lookup-service

# printf "\ninstalling 3ppi \n"
# printf "===========================================\n"
# helm install cs ./work/thirdparty
# cd  ~/work/thirdparty
# rm Chart.lock
# helm dependency build > /dev/null 2>&1
# cd
# helm install tp  ./work/thirdparty

#kubectl get pods 

