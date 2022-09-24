
#!/usr/bin/env bash
# run tests 
WORK_DIR="$HOME/work"

declare -A test_charts=(
    [eventstreamprocessor]="esp" 
    [simulator]=sim
    [monitoring/promfana]=prom
)

#ok charts 
# [eventstreamprocessor]=evs
# [simulator]=sim
# [monitoring/promfana]=prof
# [monitoring/efk]=efk
# [account-lookup-service]=als
# [als-oracle-pathfinder]=alsp
# [centralkms]=ckms
# [centralenduserregistry]=ceur
# [emailnotifier]=email
# [centraleventprocessor]=cep
# [central]=cent
# OK -[ml-api-adapter]=apia
# [quoting-service]=qs
# [finance-portal]=fp <==deprecated and not in top level values
# [finance-portal-settlement-management]=fpsm <==deprecated and not in top level values
# [transaction-requests-service]=trs
# [bulk-centralledger]=bcl
# OK - [bulk-api-adapter]=baa
# [mojaloop-bulk]=mb
# [mojaloop-simulator]=msim
# [ml-testing-toolkit]=ttk
# [ml-testing-toolkit-cli]=ttkc
# [thirdparty]=tp
# [ml-operator]=mlo

# [forensicloggingsidecar]=fls  <== has error in V14 
# [centralledger]=cl <==contained in central
# [centralsettlement]=cs <==contained in central

declare -A CHARTS=(
        [eventstreamprocessor]=evs
        [simulator]=sim
        [monitoring/promfana]=prof
        [monitoring/efk]=efk
        [account-lookup-service]=als
        [als-oracle-pathfinder]=alsp
        [centralkms]=ckms
        [centralenduserregistry]=ceur
        [emailnotifier]=email
        [centraleventprocessor]=cep
        [central]=cent
        [ml-api-adapter]=apia
        [quoting-service]=qs
        [transaction-requests-service]=trs
        [bulk-centralledger]=bcl
        [bulk-api-adapter]=baa
        [mojaloop-bulk]=mb
        [mojaloop-simulator]=msim
        [ml-testing-toolkit]=ttk
        [ml-testing-toolkit-cli]=ttkc
        [thirdparty]=tp
        [ml-operator]=mlo
    )

if [[ $1 == "delete" ]]; then 
    for K in "${!CHARTS[@]}"
        do 
            helm delete "${CHARTS[$K]}" 
        done
else 
    for K in "${!CHARTS[@]}"
        do
            helm delete "${CHARTS[$K]}"  > /dev/null 2>&1 
            printf "\ninstalling %s \n" "$K" 
            printf "===========================================\n"
            helm install "${CHARTS[$K]}" $WORK_DIR/$K
        done 
fi
exit 1 

if [[ $1 == "delete" ]]; then 
    for chart in "${charts[@]}"
    do
        helm delete "$chart" > /dev/null 2>&1 
    done 
else 
    for chart in "${charts[@]}"
    do

        helm delete "$chart" > /dev/null 2>&1 
        printf "\ninstalling %s \n" $chart
        printf "===========================================\n"
        helm install $chart $WORK_DIR/$chart
    done 
fi 

# if [[ $1 == "delete" ]]; then 
#     for chart in "${charts[@]}"
#     do
#         helm delete "$chart" > /dev/null 2>&1 
#     done 
# else 
#     for chart in "${charts[@]}"
#     do

#         helm delete "$chart" > /dev/null 2>&1 
#         printf "\ninstalling %s \n" $chart
#         printf "===========================================\n"
#         helm install $chart $WORK_DIR/$chart
#     done 
# fi 




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

