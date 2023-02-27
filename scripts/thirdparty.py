#!/usr/bin/env python3

"""
    This script is a part of the mini-loop project which aims to make installing the Mojaloop.io helm charts really easy
    This script mod_local_miniloop.py modifies a local copy of the mojaloop helm charts so that they will deploy to current
    versions of kubernetes i.e. kubernetes version from v1.22+
    Major modifications made to the mojaloop helm packages are :
        - helm template charts: update to the current networking API and fix ingressClassName issues and modify ingress yaml structure
        - requirements.yaml files : to remove the problematic and percona helm chart that does not work with containerd
        - values.yaml files : 
            - updated to not deploy database(s) 
            - updated to have a fresh database password inserted so that the separately deployed database can be accessed i.e. no default database passwords are used
            - updated so that they work with more complex passwords than "password" :-) 
            - Sept 2022 updated to cater for mongodb -> mongodbsh change in mongodb 
            - Sept 2022 : added support for enabling thirdparty charts 

    author : Tom Daly 
    Date   : July 2022
"""

import fileinput
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

def parse_args(args=sys.argv[1:]):
    parser = argparse.ArgumentParser(description='Automate modifications across mojaloop helm charts')
    parser.add_argument("-d", "--directory", required=True, help="directory for helm charts")
    parser.add_argument("-v", "--verbose", required=False, action="store_true", help="print more verbose messages ")
    parser.add_argument("-k", "--kubernetes", type=str, default="microk8s", choices=["microk8s", "k3s" ] , help=" kubernetes distro  ")
    parser.add_argument("-t", "--thirdparty", required=False, action="store_true", help="enable thirdparty charts ")

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
    
    ingress_cn = set_ingressclassname(args.kubernetes)
    script_path = Path( __file__ ).absolute()
    mysql_values_file = script_path.parent.parent / "./etc/mysql_values.yaml"
    db_pass=gen_password()
    if (args.verbose): 
        print(f"mysql_values_file  is {mysql_values_file}")
        print(f"mysql password is {db_pass}")

    # if args.thirdparty: 
    #     print("yep ")
    # else : 
    #     print("nope")

    ## check the yaml of these files because ruamel python lib has issues with loading em 
    yaml_files_check_list = [
        'ml-operator/values.yaml',
        'emailnotifier/values.yaml'
    ]
    
    ports_array  = {
        "simapi" : "3000",
        "reportapi" : "3002",
        "testapi" : "3003",
        "https" : "80",
        "http"  : "80",
        "http-admin" : "4001",
        "http-api"  : "4002",
        "mysql" : "3306",
        "mongodb" : "27017",
        "inboundapi" : "4000",
        "outboundapi" : "4001",
        "inbound" : "{{ $config.config.thirdpartysdk.env.INBOUND_LISTEN_PORT }}",
        "outbound" : "{{ $config.config.thirdpartysdk.env.OUTBOUND_LISTEN_PORT }}"

    }

    ingress_cn = set_ingressclassname(args.kubernetes)
    print (f"ingressclassname in main is {ingress_cn}")
    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")
    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.width = 4096

    # walk the directory structure and process all the values.yaml files 
    # replace solsson kafka with kymeric
    # replace kafa start up check with netcat test (TODO check to see if this is ok) 
    # replace mysql with arm version of mysql and adjust tag on the following line (TODO: check that latest docker mysql/mysql-server latest tag is ok )
    # TODO: maybe don't do this line by line but rather read in the entire file => can match across lines and avoid the next_line_logic 
    # for now disable metrics and metrics exporting
    # replace the mojaloop images with the locally built  ones
    
    print(" ==> mod_local_miniloop : Modify helm template files (.tpl) to implement networking/v1")
    # modify the template files 
    for vf in p.rglob('*.tpl'): 
        backupfile= Path(vf.parent) / f"{vf.name}_bak"
        with FileInput(files=[str(vf)], inplace=True) as f:
            for line in f:
                line = line.rstrip()
                #replace networking v1beta1 
                line = re.sub(r"networking.k8s.io/v1beta1", r"networking.k8s.io/v1", line)
                line = re.sub(r"extensions/v1beta1", r"networking.k8s.io/v1", line )
                print(line)

    # modify the ingress.yaml files 
    print(" ==> mod_local_miniloop : Modify helm template ingress.yaml files to implement newer ingress api")
    print(f" ==> mod_local_miniloop : Modify helm template ingress.yaml implement correct ingressClassName [{ingress_cn}]")
    ing_count = 0 
    for vf in p.rglob('**/*ingress*.yaml'): 
        ing_count +=1
        backupfile= Path(vf.parent) / f"{vf.name}_bak"

        with FileInput(files=[str(vf)], inplace=True) as f:
            for line in f:
                line = line.rstrip()
                if re.search("path:", line ):
                    line_dup = line
                    line_dup = re.sub(r"- path:.*$", r"  pathType: ImplementationSpecific", line_dup)
                    print(line)
                    print(line_dup)
                elif re.search("serviceName:", line ):
                    line_dup=line
                    line_dup = re.sub(r"serviceName:.*$", r"service:", line_dup)
                    print(line_dup)
                    line=re.sub(r"serviceName:", r"  name:", line)
                    print(line)
                elif re.search("servicePort:", line ):                        
                    line_dup = line 
                    line_dup=re.sub(r"servicePort:.*$", r"  port:", line_dup)
                    line = re.sub(r"servicePort: ", r"    number: ", line)
                    # need to replace port names with numbers 
                    for pname , pnum  in ports_array.items() : 
                        line = re.sub(f"number: {pname}$", f"number: {pnum}", line )
                    print(line_dup)
                    print(line)
                elif re.search("ingressClassName" , line ):
                    # skip any ingressClassname already set => we can re-run program without issue 
                    continue
                elif re.search("spec:" , line ):        
                    print(line)
                    print(f"  ingressClassName: {ingress_cn}") 
                else :  
                    print(line)

    print(f" ==> mod_local_miniloop : number of ingress.yaml files processed  [{ing_count}]")
    # put the database password file into the mysql helm chart values file 
    print(f" ==> mod_local_miniloop : generating a new database password")
    print(f" ==> mod_local_miniloop : insert new pw into [{mysql_values_file}]")
    with FileInput(files=[str(mysql_values_file)], inplace=True) as f:
        for line in f:
            line = line.rstrip()
            line = re.sub(r"password: .*$", r"password: '"+ db_pass + "'", line )
            line = re.sub(r"mysql_native_password BY .*$", r"mysql_native_password BY '" + db_pass + "';", line )
            print(line)

    print(" ==> mod_local_miniloop : Modify helm values to implement single mysql database")
    if args.thirdparty:     
        print(" ==> mod_local_miniloop : enabling thirdparty charts ")
    print(" ==> mod_local_miniloop : also update mongo command to mongosh command")
    vf_count=0
    #for vf in p.glob('**/chart-admin/*values.yaml') :
    for vf in p.glob('**/*values.yaml') :
        vf_count += 1
        config_count = 0 
        with open(vf) as f:
            if (args.verbose): 
                print(f"===> Processing file < {vf.parent}/{vf.name} > ")
            skip = False
            for fn in yaml_files_check_list : 
                if  vf == Path(fn) :
                    if (args.verbose): 
                        print(f"This yaml file needs checking skipping load/processing for now =>  {Path(fn)} ")
                    skip=True
            if not skip : 
                data = yaml.load(f)

            for x, value in lookup("mysql", data):  
                if (value.get("name") == "wait-for-mysql" ):
                    value['repository'] = "mysql"
                    value['tag'] = '8.0'
                if value.get("mysqlDatabase"): 
                    value['enabled'] = False

            # update the values files to use a mysql instance that has already been deployed 
            # and that uses a newly generated database password 
            for x, value in lookup("config", data):  
                config_count +=1        
                if  isinstance(value, dict):
                    if (value.get('db_type')): 
                        value['db_host'] = 'mldb'
                        value['db_password'] = db_pass

                    ## Sept 7th 2022:  setup to enable thirdparty 
                    ## database config is done differently for thirdparty charts 
                    ## and even differently within thirdparty charts so 
                    ## this code updates the thirdparty values and documents
                    ## where we can standardise in the future in the core 
                    ## note these values must match what is in the mini-loop/etc/mysql_values.yaml 
                    if value.get('default.json'): 
                        #print(f"ok got a default.json for values file {vf.parent/vf}")
                        tmp_dict=value['default.json']
                        if tmp_dict.get('DATABASE'): 
                            tmp_dict['DATABASE']['HOST'] = 'mldb'
                            tmp_dict['DATABASE']['PASSWORD'] = db_pass
                            tmp_dict['DATABASE']['USER'] = 'consent_oracle'
                            tmp_dict['DATABASE']['DATABASE'] = 'consent_oracle'
                    if value.get('production.json'): 
                        #tmp_dict1 = value['production.json']
                        tmp_dict1 = {}
                        if value['production.json'].get('DATABASE'):
                            tmp_dict1 = value['production.json'].get('DATABASE')
                            print(f"type of production.json is {type(tmp_dict1)}")
                            if tmp_dict1.get('connection'): 
                                tmp_dict1['connection']['host'] = 'mldb'
                                tmp_dict1['connection']['password'] = db_pass
                                print(f"DB IS >> {value['production.json'].get('DATABASE')}")
                        if tmp_dict1.get('DATABASE'): 
                            print(f">>>> ok <<<<<< got a production.json for values file {vf.parent/vf}")
                        #print(f"x = {x} and value = {value}")
                        #print(f"DB IS >> {value['production.json'].get('DATABASE')}")
                        # tmp_dict2 = tmp_dict['DATABASE']
                        # if tmp_dict2.get('connection'): 
                        #     tmp_dict2['connection']['host'] = 'mldb'
                        #     tmp_dict2['connection']['password'] = db_pass
                    if value.get('DATABASE'): 
                        print(f"ok got DATABASE for values file {vf.parent/vf}")
                        print(f"x = {x} and value = {value}")

                        
            
            # Sept 7 2022:  turn on the thirdparty charts if indicated
            if args.thirdparty:     
                for x, value in lookup ("config", data) :
                    if isinstance(value, dict):
                            value['featureEnableExtendedPartyIdType'] = 'true'
                if 'thirdparty' in data : 
                    data['thirdparty']['enabled'] = 'true'
                # turn on the ttk tests 
                if 'ml-ttk-test-setup-tp' in data : 
                    data['ml-ttk-test-setup-tp']['tests']['enabled'] = 'true'
                if 'ml-ttk-test-val-tp' in data : 
                    data['ml-ttk-test-val-tp']['tests']['enabled'] = 'true'

            # print(f"config count is {config_count}")

            ## sept 1 2022: update the mongo command to mongosh so we can use latest mongodb release
            ##              this fixes a recent issue with centraleventprocessor failing to start
            for x, value in lookup("mongodb", data):         
                if  isinstance(value, dict):
                    
                    if value.get('command'):
                        if re.match("mongo mongodb",value['command']):
                            new_cmd=re.sub("mongo mongodb","mongosh mongodb",value['command'])
                            print(f" old command is {value['command']}")
                            value['command'] = new_cmd
                            print(f" new command is {value['command']}")
        
        with open(vf, "w") as f:
            yaml.dump(data, f)

    #print(f" number of values files processed is {vf_count}")

    # now that we are inserting passwords with special characters in the password it is necessary to ensure
    # that $db_password is single quoted in the values files.
    print(" ==> mod_local_miniloop : Modify helm values, single quote db_password field to enable secure database password")
    for vf in p.glob('**/*values.yaml') :
        with FileInput(files=[str(vf)], inplace=True) as f:
            for line in f:
                line = line.rstrip()
                line = re.sub(r"\'\$db_password\'", r"$db_password", line) # makes this re-runnable. 
                line = re.sub(r'\$db_password', r"'$db_password'", line)
                print(line)
    
    # versions of k8s -> 1.20 use containerd not docker and the percona chart 
    # or at least the busybox dependency of the percona chart has an issue 
    # So here update the chart dependencies to ensure correct mysql is configured 
    # using the bitnami helm chart BUT as we are disabling the database in the 
    # values files and relying on separately deployed database this update is not really 
    # doing anything. see the mini-loop scripts dir for where and how the database deployment
    # is now done.  
    print(" ==> mod_local_miniloop : Modify helm requirements.yaml replace deprecated percona chart with current mysql")
    for rf in p.rglob('**/*requirements.yaml'):
        with open(rf) as f:
            reqs_data = yaml.load(f)
            #print(reqs_data)
        try: 
            dlist = reqs_data['dependencies']
            for i in range(len(dlist)): 
                if (dlist[i]['name'] in ["percona-xtradb-cluster","mysql"] ): 
                    dlist[i]['name'] = "mysql"
                    dlist[i]['version'] = 8.0
                    dlist[i]['repository'] = "https://charts.bitnami.com/bitnami"
                    dlist[i]['alias'] = "mysql"
                    dlist[i]['condition'] = "mysql.enabled"

        except Exception:
            continue 

        with open(rf, "w") as f:
            yaml.dump(reqs_data, f)   

    print(f"Sucessfully finished processing helm charts in directory: [{args.directory}]")      

if __name__ == "__main__":
    main(sys.argv[1:])
