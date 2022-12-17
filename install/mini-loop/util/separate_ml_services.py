#!/usr/bin/env python3

"""
    This script modifies a copy of the Mojaloop helm repo (version 14) to 
    1) separate out the database,kafka and mongodb charts from the rest of the mojaloop codebase 
    2) update to APIS current for k8s 1.22 and beyond 
    3) gets rid of default passwords from the values files 
    author : Tom Daly 
    Date   : Aug 2022
"""

import fileinput
from http.client import MULTI_STATUS
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

data = None
script_path = Path( __file__ ).absolute()

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

def update_key(key, value, dictionary):
        for k, v in dictionary.items():
            #print(f"printing k: {k} and printing key: {key} ")
            if k == key:
                #print("indeed k == key")
                dictionary[key]=value
                #print(f" the dictionary got updated in the previous line : {dictionary} ")
                #return []
            elif isinstance(v, dict):
                for result in update_key(key, value, v):
                    yield result
            elif isinstance(v, list):
                for d in v:
                    if isinstance(d, dict):
                        for result in update_key(key, value, d):
                            yield result

def gen_password(length=8, charset="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*_"):
    return "".join([secrets.choice(charset) for _ in range(0, length)])

def get_mysql_config(p,yaml,yfsl):
    # print out the mysql configs in the values files
    for vf in p.rglob('**/*values.yaml'):
        skip = False
        for fn in yfsl : 
            #print(f"Path of fn i {Path(fn)} and vf is {vf} ")
            if  vf == p / Path(fn) :
                print(f"Skipping =>  {Path(fn)} ")
                skip=True
        if not skip : 
 
            with open(vf) as f:
                data = yaml.load(f)
            parent_node=""
            for x, value in lookup("mysql", data):  
                # if (len(x)) >=2:
                #     parent_node = x[len(x)-2]
                #     print(f"vf.parent.parent is {vf.parent.parent}") 
                #     print(f" mysql config location : {x}")
                #     print(f" excluding parent node {parent_node}")
                # # print(f" mysql config location : {x}")
                # # print(f" mysql config content : {value}")
                if len(x) < 2 :
                    print(f"vf.parent.parent is {vf.parent}") 
                    print(f" mysql config location : {x}")
                    print(f" mysql config content : {value}")

def update_db_settings(p,host,pw,yfsl):
    # update the db_hosts settings to reflect the external database 

    print(f"  updating db_hosts settings")
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/values.yaml'):
        skip = False
        for fn in yfsl : 
            if  vf == p / Path(fn) :
                print(f"Skipping =>  {Path(fn)} ")
                skip=True
        if not skip : 
            backupfile= Path(vf.parent) / f"{vf.name}_bak"
            print(f"{vf} : {backupfile}")
            copyfile(vf, backupfile)
            with FileInput(files=[vf], inplace=True) as f:
                for line in f:
                    line = line.rstrip()
                    line = re.sub(r"(\s+)db_host:.*$",r"\1db_host: "+host,line)
                    line = re.sub(r"(\s+)db_password:.*$",r"\1db_password: "+pw,line)
                    print(line)


# def update_mysql(p);
# # modify the ingress.yaml files to use the latest networking API
# print(" ==> Modify helm template ingress.yaml files to implement newer ingress")
# print(f" ==> Modify helm template ingress.yaml implement correct ingressClassName [{ingress_cn}]")
# for vf in p.rglob('*/ingress.yaml'): 
#     backupfile= Path(vf.parent) / f"{vf.name}_bak"

#     with FileInput(files=[vf], inplace=True) as f:
#         for line in f:
#             line = line.rstrip()
#             if re.search("path:", line ):
#                 line_dup = line
#                 line_dup = re.sub(r"- path:.*$", r"  pathType: ImplementationSpecific", line_dup)
#                 print(line)
#                 print(line_dup)
#             elif re.search("serviceName:", line ):
#                 line_dup=line
#                 line_dup = re.sub(r"serviceName:.*$", r"service:", line_dup)
#                 print(line_dup)
#                 line=re.sub(r"serviceName:", r"  name:", line)
#                 print(line)
#             elif re.search("servicePort:", line ):                        
#                 line_dup = line 
#                 line_dup=re.sub(r"servicePort:.*$", r"  port:", line_dup)
#                 line = re.sub(r"servicePort: ", r"    number: ", line)
#                 # need to replace port names with numbers 
#                 for pname , pnum  in ports_array.items() : 
#                     line = re.sub(f"number: {pname}$", f"number: {pnum}", line )
#                 print(line_dup)
#                 print(line)
#             elif re.search("ingressClassName" , line ):
#                 # skip any ingressClassname already set => we can re-run program without issue 
#                 continue
#             elif re.search("spec:" , line ):        
#                 print(line)
#                 print(f"  ingressClassName: {ingress_cn}") 
#             else :  
#                 print(line)



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
   
    yaml_files_skip_list = [
        'example-mojaloop-backend/values.yaml'
    ]
    # mysql_values_file = script_path.parent.parent / "./etc/mysql_values.yaml"
    # db_pass=gen_password()
    if (args.verbose): 
        print(f"mysql_values_file  is {mysql_values_file}")
        print(f"mysql password is {db_pass}")

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")
    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.width = 4096

    db_host = "mysqldb"
    db_pass = "HY#Mz%_z"

   # get_mysql_config(p,yaml,yaml_files_skip_list)
    update_db_settings(p,db_host,db_pass,yaml_files_skip_list)
   

if __name__ == "__main__":
    main(sys.argv[1:])