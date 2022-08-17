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
from pathlib import Path
from shutil import copyfile 
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

def update_ingress():
    # modify the ingress.yaml files to use the latest networking API
    print(" ==> Modify helm template ingress.yaml files to implement newer ingress")
    print(f" ==> Modify helm template ingress.yaml implement correct ingressClassName [{ingress_cn}]")
    for vf in p.rglob('*/ingress.yaml'): 
        backupfile= Path(vf.parent) / f"{vf.name}_bak"

        with FileInput(files=[vf], inplace=True) as f:
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
    script_path = Path( __file__ ).absolute()
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

    ingress_cn = set_ingressclassname(args.kubernetes)
    print (f"ingressclassname in main is {ingress_cn}")
    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")
    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)
    yaml.width = 4096


    update_charts_yaml(p,yaml)
    #update_ingress(p,yaml)
    

     

if __name__ == "__main__":
    main(sys.argv[1:])
