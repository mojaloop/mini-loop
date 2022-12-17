#!/usr/bin/env bash
# a demo / test myswl deployment 

echo "To test this mysql instance " ....
echo "kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- mysql -h mysql -ppassword"
echo "to test centyral ledger DB use .... " 
echo " kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- mysql -h mysql-cl -P 3306 -u central_ledger --password=password  central_ledger " 
echo " mysql -h mysql-cl -P 3306 -u central_ledger --password=password  central_ledger -ss -N -e 'select is_locked from migration_lock;'
kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- "until result=$(mysql -h mysql-cl -P 3306 -u central_ledger --password=password  central_ledger -ss -N -e 'select is_locked from migration_lock;') && \
eval 'echo is_locked=$result' && if [ -z $result ]; then false; fi && if [ $result -ne 0 ]; then false; fi; echo waiting for MySQL; sleep 2
k  run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- mysql -h mysqldb -u account_lookup --password=HY#Mz%_z account_lookup

#kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- "until result=$(mysql -h mysql-cl -P 3306 -u central_ledger --password=password  central_ledger -ss -N -e 'select is_locked from migration_lock;') && \
#eval 'echo is_locked=$result' && if [ -z $result ]; then false; fi && if [ $result -ne 0 ]; then false; fi; do echo waiting for MySQL; sleep 2; done;

#"$(mysql -h $db_host -P $db_port -u $db_user --password=$db_password  $db_database -ss -N -e 'select is_locked from migration_lock;') && eval 'echo is_locked=$result' && if [ -z $result ]; then false; fi && if [ $result -ne 0 ]; then false; fi; do echo waiting for MySQL; sleep 2; done;"