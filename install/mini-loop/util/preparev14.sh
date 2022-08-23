
#!/usr/bin/env bash
# temp script to aid in testing of mods to v14 feat/2352
rm -rf $HOME/work 
cp -r $HOME/helm $HOME/work 
cp -r $HOME//mini-loop/install/mini-loop/etc/bitnami/common $HOME/work
$HOME/mini-loop/install/mini-loop/util/do_rel14x.py -d $HOME/work 
helm package $HOME/work/common 
