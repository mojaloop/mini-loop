#!/usr/bin/env python3

"""
    This script modifies a copy of the Mojaloop helm repo (version 14) to 
    - move dependencies in the requirements.yaml to Charts.yaml
    - update the apiVersion for helm in all the Charts.yaml to 2 
    - updates the ingress if there is one with the ingress from bitnami
    - add the common dependency to each chart that already has an ingress
    - updates the values files for the new ingress settings 
    - update maintainers in chart.yaml to include tomd@crosslaketech
    - update the thirdparty charts.yaml to have the correct local common lib
    - _helper.tpl updated to use 
    todo
    - update _helpers.tpl to remove ingress version logic completely 
    - handle ./finance-portal-settlement-management/templates/operator-settlement-ingress.yaml
             ./finance-portal-settlement-management/templates/settlement-management-ingress.yaml
             ./mojaloop-simulator/templates/ingress-thirdparty-sdk.yaml
             ./finance-portal/templates/backend-ingress.yaml
             ./finance-portal/templates/frontend-ingress.yaml
    - ensure the updated values files have the correct hostname 
    - ensure the updated values files have the correct port number  
    - update config/default.json files for values.ingress.api.host or similar to .Values.ingress.hostname 

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
from ruamel.yaml import CommentedMap
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

def insert(d, n):
    if isinstance(n, CommentedMap):
        for k in n:
            if k in d :
                d[k] = update(d[k], n[k])
            else:
                 d[k].append(n[k])
            if k in n.ca._items and n.ca._items[k][2] and \
               n.ca._items[k][2].value.strip():
                d.ca._items[k] = n.ca._items[k]  # copy non-empty comment
    else:
        d.append(n)
    return d

def update(d, n):
    if isinstance(n, CommentedMap):
        for k in n:
            d[k] = update(d[k], n[k]) if k in d else n[k]
            if k in n.ca._items and n.ca._items[k][2] and \
               n.ca._items[k][2].value.strip():
                d.ca._items[k] = n.ca._items[k]  # copy non-empty comment
    else:
        d = n
    return d

def set_ingress(p, yaml,set_enabled=False):
    # copy in the bitnami template ingress values 
    for vf in p.rglob('**/mojaloop/*values.yaml'):
        print(f"===> Processing file < {vf.parent}/{vf.name} > ")   
        data=[]
        # load the values file 
        with open(vf) as f:
            data = yaml.load(f)

        ing_sections_count = 0 
        turned_on_count  = 0
        already_on_count = 0 
        enabled_blank_cnt = 0 
        # get the top level yaml structures
        for x, value in lookup('ingress', data):
            ing_sections_count += 1
            if len(x) >= 2 : 
                parent_node = x[len(x)-2]
            else:     
                print(f"no parent x = {x}")
            if value.get('enabled') == True:
                already_on_count +=1 
            elif value.get('enabled') == False:
                turned_on_count += 1 
            else : 
                print(f" no enabled setting for ingress for {parent_node}")
                enabled_blank_cnt += 1 
            value['enabled'] = set_enabled
            print(f"enabled ingress for {parent_node}")
                # print(f"FAILED to enable ingress for {parent_node}")
        with open(vf, "w") as vfile:
            yaml.dump(data, vfile)

    print(f" total number of ingress sections found [{ing_sections_count}]")
    print(f" total number of ingress sections were previously enabled [{already_on_count}]")
    print(f" total number of ingress sections were just now  enabled [{turned_on_count}]")
    print(f" total number of ingress sections w/o enabled setting [{enabled_blank_cnt}]")

       
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

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    set_ingress(p,yaml,set_enabled=True)
 
if __name__ == "__main__":
    main(sys.argv[1:])