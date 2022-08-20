#!/usr/bin/env python3

"""
    This script modifies a copy of the Mojaloop helm repo (version 14) to 
    1) move dependencies in the requirements.yaml to Charts.yaml
    2) update the apiVersion for helm in the Charts.yaml to 2 
    todo
    - updates the ingress if there is one with the ingress from bitnami
    - updates the values files for the new ingress settings 

    author : Tom Daly 
    Date   : Aug 2022
"""

import fileinput
from operator import sub
import sys
import re
import argparse
import os 
import shutil
from pathlib import Path
from fileinput import FileInput
import fileinput 
from ruamel.yaml import YAML
import secrets

data = None
script_path = Path( __file__ ).absolute()

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
            #print(f">>> printing k: {k} and printing key: {key} ")
            if k == key:
                #print(f">>>>indeed {k} == {key}")
                dictionary[key]=value
                print(f">>>>> the dictionary got updated in the previous line : {dictionary[key]} ")
            elif isinstance(v, dict):
                for result in update_key(key, value, v):
                    yield result
            elif isinstance(v, list):
                for d in v:
                    if isinstance(d, dict):
                        for result in update_key(key, value, d):
                            yield result

def update_charts_yaml (p,yaml):
    # copy the dependencies from requirements.yaml to the Charts.yaml
    # update the helm api to apiVersion 2 
    print(" ==> rel14x : copy dependencies from requirements.yaml to Charts.yaml")
    for rf in p.rglob('**/*requirements.yaml'):
        
        rf_parent=rf.parent
        cf=rf.parent / 'Chart.yaml'
        print(f"Processing requirements file {rf}")

        with open(rf) as f:
            reqs_data = yaml.load(f)

           # print(reqs_data)
            try: 
                dlist = reqs_data['dependencies']
                for i in range(len(dlist)): 
                    if (dlist[i]['name'] in ["percona-xtradb-cluster","mysql"] ): 
                        dlist[i]['name'] = "mysql"
                        dlist[i]['version'] = 8.0
                        dlist[i]['repository'] = "https://charts.bitnami.com/bitnami"
                        dlist[i]['alias'] = "mysql"
                        dlist[i]['condition'] = "mysql.enabled"

                # add the common library to dependencies
                common_lib_dict={ 
                    "name" : "common" , 
                    "repository" : "file://../common" , 
                    "tags" : "moja-common" ,
                    "version" : "2.0.0" }
                dlist.append(common_lib_dict)

                print(f"Processing chart file {cf} ")
                print("  ==> setting  helm apiVersion=2")
                print("  ==> copy dependencies from requirements.yaml")
                with open(cf) as cfile: 
                    cfdata = yaml.load(cfile);
                    cfdata['apiVersion']="v2"
                    cfdata['dependencies']=dlist

                with open(cf, "w") as cfile:
                    yaml.dump(cfdata, cfile)

            except Exception as e: 
                print(f" Exception {e} \n")        
                continue 

    print(f" Deleting requirements files {rf}")
    for rf in p.rglob('**/*requirements.yaml'):        
         print(f"  ==> unlink/delete requirements: {rf}")    
         rf.unlink(missing_ok=True)

def update_ingress(p, yaml,ports_array):
    # Copy the bitnami inspired ingress over the existing ingress
    print("Copying in the bitnami inspired ingress.yaml ")
    bn_ingress_file = script_path.parent.parent / "./etc/bitnami/bn_ingress.yaml"
    print(f"bn_ingress_file is : {bn_ingress_file}")
    # for each existing ingress, write the new ingress content over it
    for ingf in p.rglob('*/ingress.yaml'): 
        print(f" ==> copying new ingress to {ingf} ")
        shutil.copy(bn_ingress_file, ingf)

def update_values_for_ingress(p, yaml):
    # copy in the bitemplate ingress values 
    bivf = script_path.parent.parent / "./etc/bitnami/bn_ingress_values.yaml"
    print(f" Bitnami values loaded from :  {bivf}")
    with open(bivf) as f:
        bivf_data = yaml.load(f)

        print(f"ingress data is : {bivf_data}")
        print(f"bivf is {type(bivf_data)}")
    # xlist= bivf_data['ingress']
    # print(f"xlist data is : {xlist}")
    #sys.exit()
    origin_ingress_hostname=""
    origin_path=""
    for vf in p.rglob('*account*/*values.yaml'):
        print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        data=[]
        with open(vf) as f:
            data = yaml.load(f)
            ## clear the existing data/values from the ingress 
            ## then copy in the new values 

            toplist = [] 
            hostname=""
            # get the top level yaml structures
            for x, value in lookup('ingress', data):
                toplist = toplist + [x]
            # for each top level structure 
            # lookup its ingress if it has one 
            for i in toplist:
                for x, value in lookup(i[0], data):
                    # for some reason need to reset this data 
                    # or it fails to insert more than once 
                    with open(bivf) as f:
                       newdata = yaml.load(f)
                    if value.get("ingress"):
                        if value.get('ingress', {} ).get('hosts'):
                            hostname=value['ingress']['hosts']
                            print(f"type of hostname is {type(hostname)}")
                        # for y, values1 in lookup('hosts', value):
                        #     #print(f"y = {y}, next y is {next(y)} ")
                        #     print(f"values1 is {values1}")
                        #     #print(f"hostname is {values1['hosts']}")

                        del value['ingress']
                        value['ingress'] = newdata
                
                #if (isinstance(value, list)):
                #     print("yep is list")
                #     value.clear()
                # elif (isinstance(value, dict)):
                #     value_copy=value.copy()
                #     for k in  value_copy.keys():
                #         del value[k]
                #print(f"dir for CommentedMap = {dir(yaml)}")
                    # for z , value1 in lookup('ingress',bivf_data):

                    #         value.insert(2,k,v)
                    # if (isinstance(bivf_data, list)):
                    #     printf("BIVF is a list ")
                    #     i_list = bivf_data['ingress']
                    #     for i in range(len(i_list)): 
                    #         print(f" new ing value is : {i_list[i]}")
                    # elif (isinstance(bivf_data, dict)):
                    #     print("BIVF is a dictionary ")
                    #     for k ,v in enumerate(bivf_data):
                    #         print(f" >> k = {k} and value = {v} ")
                    #         # value.insert(1,"tom", "fred6")
                    #         # value.inseet(2,)

                #yaml.dump(data, sys.stdout)        

        
            #del data['ingress']
            # for x, value in lookup('ingress', data):  
            #     list(update_key('command', 'until nc -vz -w 1 $kafka_host $kafka_port; do echo waiting for Kafka; sleep 2; done;' , value))
            #     x = {"tom":"fred2"} 
            #     print(f"x is << {x} >>  ")
            #     print(f"value is << {value} >> ")
            #     value={"tom":"fred"} 
            #     print(f"NEW value is << {value} >> ") 

        with open(vf, "w") as vfile:
            yaml.dump(data, vfile)
             

            # update the values files to use a mysql instance that has already been deployed 
            # and that uses a newly generated database password 
            # for x, value in lookup("config", data):         
            #     if  isinstance(value, dict):
            #         if (value.get('db_type')): 
            #             value['db_host'] = 'mldb'
            #             value['db_password'] = db_pass

            ### need to set nameOverride  for mysql for ml-testing-toolkit as it appears to be missing
            # if vf == Path('mojaloop/values.yaml') : 
            #     print("Updating the ml-testing-toolkit / mysql config ")
            #     for x, value in lookup("ml-testing-toolkit", data):  
            #         value['mysql'] = { "nameOverride" : "ttk-mysql" }

        with open(vf, "w") as f:
            yaml.dump(data, f)




def parse_args(args=sys.argv[1:]):
    parser = argparse.ArgumentParser(description='Automate modifications across mojaloop helm charts')
    parser.add_argument("-d", "--directory", required=True, help="directory for helm charts")
    parser.add_argument("-v", "--verbose", required=False, action="store_true", help="print more verbose messages ")
    parser.add_argument("-k", "--kubernetes", type=str, default="microk8s", choices=["microk8s", "k3s" ] , help=" kubernetes distro  ")

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
   
    mysql_values_file = script_path.parent.parent / "./etc/mysql_values.yaml"
    db_pass=gen_password()
    if (args.verbose): 
        print(f"mysql_values_file  is {mysql_values_file}")
        print(f"mysql password is {db_pass}")

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
        "inboundapi" : "{{ $config.config.schemeAdapter.env.INBOUND_LISTEN_PORT }}",
        "outboundapi" : "{{ $config.config.schemeAdapter.env.OUTBOUND_LISTEN_PORT }}"
    }

    #ingress_cn = set_ingressclassname(args.kubernetes)
    #print (f"ingressclassname in main is {ingress_cn}")
    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")
    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)
    yaml.width = 4096

    #update_charts_yaml(p,yaml)
    #update_ingress(p,yaml,ports_array)  
    update_values_for_ingress(p,yaml)

if __name__ == "__main__":
    main(sys.argv[1:])

