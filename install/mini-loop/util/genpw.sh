#!/usr/bin/env bash

PW=`< /dev/urandom tr -dc A-Za-z0-9_ | head -c10`
echo $PW
 
perl -p -i.bak -e "s/^(\s+)password:.*$/\1password: $PW/g" /tmp/x

