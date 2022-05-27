#!/usr/bin/env bash
# install or delete small apache test app

function showUsage {
  echo  "USAGE: $0 [install | uninstall ] "
  exit
}

function install {
  echo "install apache webserver "
 
}

function uninstall {
  echo "uninstalling apache webserver"

}

###################### Main ##########################################

while [[ $# -gt 0 ]] ; do
  if [[ $1 == "install" ]] ; then
    install
  elif [[ $1 == "uninstall" ]] ; then
    uninstall
  elif [[ $1 == "-h" ]] ; then
    showUsage
  fi
  shift
done

exit
