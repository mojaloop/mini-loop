#!/usr/bin/env python3

"""
    This script is a part of the mini-loop project which aims to make installing the Mojaloop.io helm charts really easy
    This script mojaloop-configure.py modifies a local copy of the mojaloop helm charts to support user configuration options

    author : Tom Daly 
    Date   : Feb 2023
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
 
def modify_values_for_thirdparty(p,yaml,verbose=False):
    print(" ==> mojaloop-configure : Modify values to enable thirdparty")
    vf = p / "mojaloop" / "values.yaml"
    with open(vf) as f:
        if (verbose): 
            print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        data = yaml.load(f)
        data['account-lookup-service']['account-lookup-service']['config']['featureEnableExtendedPartyIdType'] = 'true'
        data['account-lookup-service']['account-lookup-service-admin']['config']['featureEnableExtendedPartyIdType'] = 'true'
        if 'thirdparty' in data : 
            data['thirdparty']['enabled'] = 'true'
        # turn on the ttk tests 
        if 'ml-ttk-test-setup-tp' in data : 
            data['ml-ttk-test-setup-tp']['tests']['enabled'] = 'true'
        if 'ml-ttk-test-val-tp' in data : 
            data['ml-ttk-test-val-tp']['tests']['enabled'] = 'true'
    with open(vf, "w") as f:
        yaml.dump(data, f)

def modify_values_for_bulk(p,yaml,verbose=False):
    print(" ==> mojaloop-configure : Modify values to enable bulk")
    vf = p / "mojaloop" / "values.yaml"
    with open(vf) as f:
        if (verbose): 
            print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        data = yaml.load(f)
        data['mojaloop-bulk']['enabled'] = 'true-fred'
        data['account-lookup-service']['account-lookup-service-admin']['config']['featureEnableExtendedPartyIdType'] = 'true'
        if 'thirdparty' in data : 
            data['thirdparty']['enabled'] = 'true'
        # turn on the ttk tests 
        if 'ml-ttk-test-val-bulk' in data : 
            data['ml-ttk-test-val-bulk']['tests']['enabled'] = 'fred'
    with open(vf, "w") as f:
        yaml.dump(data, f)

def modify_values_for_dns_domain_name:
    # modify ingress hostname in values file to use DNS name     
    print(f" ==> mojaloop-configure : Modify values to use dns domain name {domain_name} )
    #DNSNAME="eastus.cloudapp.azure.com"
    #DNSNAME="fred1"
    for vf in p.glob('**/*values.yaml') :
        with FileInput(files=[str(vf)], inplace=True) as f:
            for line in f:
                line = line.rstrip()
                line = re.sub(r"(\s+)hostname: (\S+).local", f"\\1hostname: \\2.{args.domain_name}", line)
                line = re.sub(r"(\s+)host: (\S+).local", f"\\1host: \\2.{args.domain_name}", line)
                line = re.sub(r"testing-toolkit.local", f"testing-toolkit.{args.domain_name}", line)
                print(line)


def parse_args(args=sys.argv[1:]):
    parser = argparse.ArgumentParser(description='Automate modifications across mojaloop helm charts')
    parser.add_argument("-d", "--directory", required=True, help="directory for helm charts")
    parser.add_argument("-v", "--verbose", required=False, action="store_true", help="print more verbose messages ")
    parser.add_argument("-t", "--thirdparty", required=False, action="store_true", help="enable thirdparty charts and tests  ")
    parser.add_argument("-b", "--bulk", required=False, action="store_true", help="enable bulk-api charts and tests  ")
    parser.add_argument("--domain_name", type=str, required=False, default=None, help="e.g. mydomain.com   ")


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

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    if args.thirdparty:
        modify_values_for_thirdparty(p,yaml,args.verbose)
    if args.bulk:
        modify_values_for_bulk(p,yaml,args.verbose)    
 
if __name__ == "__main__":
    main(sys.argv[1:])
