#!/usr/bin/env bash
# install mojaloop using Lewis Daly's temporary version
# 18th April 20202

# set locations 
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
# @todo helm uninstall any previous charts OR message that user should re-provision VM 
# if mojaloop is already running , in any case check if it is and bail.
helm install moja http://localhost:8000/mojaloop-9.3.0.tgz 

# we are finished with the http server, so clean it up by killing it.
py_proc=`ps -eaf | grep -i "python3 -m http.server" | grep -v grep | awk '{print $2}'`
kill $py_proc 


