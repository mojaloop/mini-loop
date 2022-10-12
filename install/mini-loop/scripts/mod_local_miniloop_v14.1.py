#!/usr/bin/env python3

"""
    This script is a part of the mini-loop project which aims to make installing the Mojaloop.io helm charts really easy
    This script mod_local_miniloop_v14.1.py modifies a local copy of the mojaloop helm charts so that they will deploy to current
    versions of kubernetes i.e. kubernetes version from v1.22+ using (and this is important) Mojaloop version 14.1+
    Note: Mojaloop v14.1+ includes updates to the helm charts so as to support networking/v1 => mini-loop and this script 
          no longer need to make those changes to the charts
    Major modifications made to the mojaloop helm packages are :
        - helm template charts: 
        - Charts.yaml files : to remove the problematic and percona helm chart that does not work with containerd
        - values.yaml files : 
            - updated to not deploy database(s) 
            - updated to have a fresh database password inserted so that the separately deployed database can be accessed i.e. no default database passwords are used
            - updated so that they work with more complex passwords than "password" :-) 

    author : Tom Daly 
    Date   : Oct 2022
"""

import fileinput
#from http.client import MULTI_STATUS
from operator import sub
import sys
import re
import argparse
import os 
from pathlib import Path
from shutil import copyfile 
#import yaml
from fileinput import FileInput
import fileinput 
from ruamel.yaml import YAML
import secrets

data = None

def gen_password(length=8, charset="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*_"):
    return "".join([secrets.choice(charset) for _ in range(0, length)])

def set_ingressclassname (distro) : 
    nginxclassname_array = { "microk8s" : "public", "k3s" : "nginx" } 
    return (nginxclassname_array[distro])

def print_debug(x1, x2, c=0) :  
    print("******************")
    print(f" [{c}]: {x1} " )
    print(f" [{c}]: {x2} " )
    print("******************")
                
def lookup(sk, d, path=[]):
   # lookup the values for key(s) sk return as list the tuple (path to the value, value)
   if isinstance(d, dict):
       for k, v in d.items():       
           if k == sk:
               yield (path + [k], v)
           for res in lookup(sk, v, path + [k]):
               yield res
   elif isinstance(d, list):
       for item in d:
           for res in lookup(sk, item, path + [item]):
               yield res

"""
update_key: recursively 
"""
def update_key(key, value, dictionary):
        for k, v in dictionary.items():
            #print(f"printing k: {k} and printing key: {key} ")
            if k == key:
                #print("indeed k == key")
                dictionary[key]=value
                #print(f" the dictionary got updated in the previous line : {dictionary} ")
            elif isinstance(v, dict):
                for result in update_key(key, value, v):
                    yield result
            elif isinstance(v, list):
                for d in v:
                    if isinstance(d, dict):
                        for result in update_key(key, value, d):
                            yield result


   # walk the directory structure and process all the values.yaml files 
    # replace solsson kafka with kymeric
    # replace kafa start up check with netcat test (TODO check to see if this is ok) 
    # replace mysql with arm version of mysql and adjust tag on the following line (TODO: check that latest docker mysql/mysql-server latest tag is ok )

def config_database_dependencies(p,yaml):
    # versions of k8s -> 1.20 use containerd not docker and the percona chart 
    # or at least the busybox dependency of the percona chart has an issue 
    # So here update the chart dependencies to ensure correct mysql is configured 
    # using the bitnami helm chart BUT as we are disabling the database in the 
    # values files and relying on separately deployed database this update is not really 
    # doing anything. see the mini-loop scripts dir for where and how the database deployment
    # is now done.  
    print(" ==> mod_local_miniloop : Modify helm Chart.yaml replace deprecated percona chart with current mysql")
    for cf in p.rglob('**/*Chart.yaml'):
        with open(cf) as f:
            cfdata = yaml.load(f)
            #print(reqs_data)
        for x, value in lookup('dependencies', cfdata):
            if(isinstance(value,list)) :   
                for i in range(len(value)): 
                    if (value[i]['name'] in ["percona-xtradb-cluster","mysql"] ): 
                        value[i]['name'] = "mysql"
                        value[i]['version'] = 8.0
                        value[i]['repository'] = "https://charts.bitnami.com/bitnami"
                        value[i]['alias'] = "mysql"
                        value[i]['condition'] = "mysql.enabled"

        #yaml.dump(cfdata, sys.stdout)
        with open(cf, "w") as f:
            yaml.dump(cfdata, f)  

def refresh_db_password (mysql_values_file,db_pass):
    # put the database password file into the mysql helm chart values file 
    print(f" ==> mod_local_miniloop_v14.1 : generating a new database password")
    print(f" ==> mod_local_miniloop_v14.1  : insert new pw into [{mysql_values_file}]")
   
    with FileInput(files=[mysql_values_file], inplace=True) as f:
        for line in f:
            line = line.rstrip()
            line = re.sub(r"password: .*$", r"password: '"+ db_pass + "'", line )
            line = re.sub(r"mysql_native_password BY .*$", r"mysql_native_password BY '" + db_pass + "';", line )
            print(line)

def modify_values_for_database (p,yaml,db_pass,verbose=False) : 
    print(" ==> mod_local_miniloop : Modify helm values to implement single mysql database")
    for vf in p.glob('**/*values.yaml') :
        with open(vf) as f:
            data = yaml.load(f)
            if (verbose): 
                print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        
            for x, value in lookup("mysql", data):  
                if (value.get("name") == "wait-for-mysql" ):
                    value['repository'] = "mysql"
                    value['tag'] = '8.0'
                if value.get("mysqlDatabase"): 
                    value['enabled'] = False

            # update the values files to use a mysql instance that has already been deployed 
            # and that uses a newly generated database password 
            for x, value in lookup("config", data):         
                if  isinstance(value, dict):
                    if (value.get('db_type')): 
                        value['db_host'] = 'mldb'
                        value['db_password'] = db_pass

        with open(vf, "w") as f:
            yaml.dump(data, f)

def fix_quotes_for_database_values(p): 
    # now that we are inserting passwords with special characters in the password it is necessary to ensure
    # that $db_password is single quoted in the values files.
    print(" ==> mod_local_miniloop : Modify helm values, single quote db_password field to enable secure database password")
    for vf in p.glob('**/*values.yaml') :
        with FileInput(files=[vf], inplace=True) as f:
            for line in f:
                line = line.rstrip()
                line = re.sub(r"\'\$db_password\'", r"$db_password", line) # makes this re-runnable. 
                line = re.sub(r'\$db_password', r"'$db_password'", line)
                print(line)
    
 
def parse_args(args=sys.argv[1:]):
    parser = argparse.ArgumentParser(description='Automate modifications across mojaloop helm charts')
    parser.add_argument("-d", "--directory", required=True, help="directory for helm charts")
    parser.add_argument("-v", "--verbose", required=False, action="store_true", help="print more verbose messages ")

    args = parser.parse_args(args)
    if len(sys.argv[1:])==0:
        parser.print_help()
        parser.exit()
    return args

##################################################
# main
##################################################
def main(argv) :
    args=parse_args()
    
    #ingress_cn = set_ingressclassname(args.kubernetes)
    script_path = Path( __file__ ).absolute()
    mysql_values_file = script_path.parent.parent / "./etc/mysql_values.yaml"
    db_pass=gen_password()
    if (args.verbose): 
        print(f"mysql_values_file  is {mysql_values_file}")
        print(f"mysql password is {db_pass}")

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    config_database_dependencies(p,yaml)  # replace percona chart with mysql bitnami one in dependencies
    modify_values_for_database (p,yaml,db_pass,args.verbose)
    refresh_db_password (mysql_values_file,db_pass)
    fix_quotes_for_database_values(p)
 
if __name__ == "__main__":
    main(sys.argv[1:])
