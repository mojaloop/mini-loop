#!/usr/bin/env bash
# script to aid in testing of mods to v14 for feat/2352
rm -rf $HOME/work1
cp -r $HOME/td-helm $HOME/work1 
$HOME/mini-loop/install/mini-loop/scripts/mod_local_miniloop_v14.1.py -d ~/work1
if [ $? -ne 0 ]; then
    exit 1 
fi


if [[ "$1" == "deploy" ]]; then 
    cd $HOME/work1
    ./package.sh
    helm install mltest --dry-run ./mojaloop
fi

