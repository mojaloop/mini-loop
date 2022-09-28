
#!/usr/bin/env bash
# temp script to aid in testing of mods to v14 feat/2352
rm -rf $HOME/work 
cp -r $HOME/helm $HOME/work 
$HOME/mini-loop/install/mini-loop/util/do_rel14x_mods.py -d $HOME/work 
#$HOME/mini-loop/install/mini-loop/util/wip.py -d $HOME/work 
#cp -r $HOME//mini-loop/install/mini-loop/etc/bitnami/common $HOME/work
#helm package $HOME/work/common 
#mv $HOME/mini-loop/install/mini-loop/util/common-2.0.0.tgz $HOME/work
#cp $HOME/work/common-2.0.0.tgz $HOME/work/repo
#cp $HOME/mini-loop/install/mini-loop/etc/package.sh $HOME/work
cd $HOME/work; find . -name requirements.lock -type f -exec rm {} \;

if [[ "$1" == "d" ]]; then 
    cd $HOME/work
    ./package.sh
    helm install mltest --dry-run ./mojaloop
fi

