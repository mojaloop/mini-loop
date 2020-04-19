#!/usr/bin/env bash
# install mojaloop using Lewis Daly's temporary version
# 18th April 20202

# add /etc/hosts entries for local access
export ENDPOINTS='127.0.0.1       localhost forensic-logging-sidecar.local central-kms.local \
central-event-processor.local email-notifier.local central-ledger.local 
central-settlement.local ml-api-adapter.local account-lookup-service.local 
 account-lookup-service-admin.local quoting-service.local moja-simulator.local 
 central-ledger central-settlement ml-api-adapter account-lookup-service 
 account-lookup-service-admin quoting-service simulator host.docker.internal'

read -r -d '' VAR <<'EOF'
    localhost forensic-logging-sidecar.local central-kms.local
    central-event-processor.local email-notifier.local central-ledger.local 
EOF

echo $VAR

exit
perl -p -i.bak -e 's/127\.0\.0\.1.*localhost.*$/$ENV{ENDPOINTS} /' ./tmp/hosts
exit
set -x 

MOJALOOP_CHARTS_DIR=/vagrant/vessels-tech/helm
MJALOOP_CHARTS_BRANCH='fix/219-kubernetes-17'

cd /vagrant 
rm -rf $MOJALOOP_CHARTS_DIR
git clone https://github.com/vessels-tech/helm.git $MOJALOOP_CHARTS_DIR
cd $MOJALOOP_CHARTS_DIR
git checkout -b $MJALOOP_CHARTS_BRANCH origin/$MJALOOP_CHARTS_BRANCH

./package.sh
cd $MOJALOOP_CHARTS_DIR/repo
pwd
python3 -m http.server & 

#helm uninstall moja 
helm install moja http://localhost:8000/mojaloop-9.3.0.tgz
ps 

py_proc=`ps -eaf | grep -i "python3 -m http.server" | grep -v grep | awk '{print $2}'`
kill $py_proc 

# add /etc/hosts entries for local access
export ENDPOINTS='127.0.0.1       localhost forensic-logging-sidecar.local central-kms.local \
central-event-processor.local email-notifier.local central-ledger.local \
central-settlement.local ml-api-adapter.local account-lookup-service.local \
 account-lookup-service-admin.local quoting-service.local moja-simulator.local \
 central-ledger central-settlement ml-api-adapter account-lookup-service \
 account-lookup-service-admin quoting-service simulator host.docker.internal'

echo $ENDPOINTS

