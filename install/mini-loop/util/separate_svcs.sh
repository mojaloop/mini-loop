#!/usr/bin/env bash
# script to aid in testing of mods to v14 for feat/2352
rm -rf $HOME/work 
cp -r $HOME/td-helm $HOME/work 
#cp -r $HOME/td-helm/example-mojaloop-backend $HOME/work
$HOME/mini-loop/install/mini-loop/util/separate_ml_services.py -d $HOME/work 

# replace db_host: with example backend db


if [ $? -ne 0 ]; then
    exit 1 
fi
# $HOME/mini-loop/install/mini-loop/util/fix-v14-formatting.py -d $HOME/work 
# if [ $? -ne 0 ]; then
#     exit 1 
# fi
# $HOME/mini-loop/install/mini-loop/util/pr-review-fixes.py -d $HOME/work 
# if [ $? -ne 0 ]; then
#     exit 1 
# fi
# cd $HOME/work; find . -name requirements.lock -type f -exec rm {} \;


if [[ "$1" == "deploy" ]]; then 
    cd $HOME/work
    ./package.sh
    helm install mltest --dry-run ./mojaloop
fi

