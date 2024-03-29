#!/usr/bin/env python3

"""
    This script is a part of the mini-loop project which aims to make installing the Mojaloop.io helm charts really easy
    This script mojaloop-configure.py modifies a local copy of the mojaloop helm charts to support user configuration options

    author : Tom Daly 
    Date   : Feb 2023
"""

import fileinput
import sys
import re
import argparse
from pathlib import Path
from shutil import copyfile 
from fileinput import FileInput
import fileinput 
from ruamel.yaml import YAML

data = None
                
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
        if k == key:
            dictionary[key]=value
        elif isinstance(v, dict):
            for result in update_key(key, value, v):
                yield result
        elif isinstance(v, list):
            for d in v:
                if isinstance(d, dict):
                    for result in update_key(key, value, d):
                        yield result
 
def modify_values_for_thirdparty(p,yaml,verbose=False):
    print("     <mojaloop-configure.py>  : Modify values to enable thirdparty")
    vf = p / "mojaloop" / "values.yaml"
    with open(vf) as f:
        if (verbose): 
            print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        data = yaml.load(f)
    data['account-lookup-service']['account-lookup-service']['config']['featureEnableExtendedPartyIdType'] = True
    data['account-lookup-service']['account-lookup-service-admin']['config']['featureEnableExtendedPartyIdType'] = True
    if 'thirdparty' in data : 
        data['thirdparty']['enabled'] = True
    # turn on the ttk tests 
    if 'ml-ttk-test-setup-tp' in data : 
        data['ml-ttk-test-setup-tp']['tests']['enabled'] = True
    if 'ml-ttk-test-val-tp' in data : 
        data['ml-ttk-test-val-tp']['tests']['enabled'] = True
    with open(vf, "w") as f:
        yaml.dump(data, f)

def modify_values_for_bulk(p,yaml,verbose=False):
    print("     <mojaloop-configure.py>  : Modify values to enable bulk")
    vf = p / "mojaloop" / "values.yaml"
    with open(vf) as f:
        if (verbose): 
            print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        data = yaml.load(f)
    data['mojaloop-bulk']['enabled'] = True
    data['mojaloop-ttk-simulators']['enabled'] = True
    # data['account-lookup-service']['account-lookup-service-admin']['config']['featureEnableExtendedPartyIdType'] = True
    # if 'thirdparty' in data : 
    #     data['thirdparty']['enabled'] = True
    # turn on the ttk tests 
    if 'ml-ttk-test-val-bulk' in data : 
        data['ml-ttk-test-val-bulk']['tests']['enabled'] = True
    with open(vf, "w") as f:
        yaml.dump(data, f)

def modify_values_for_dns_domain_name(p,domain_name,verbose=False):
    # modify ingress hostname in values file to use DNS name     
    print(f"      <mojaloop-configure.py> : Modify values to use dns domain name {domain_name}" )
    for vf in p.glob('**/*values.yaml') :
        with FileInput(files=[str(vf)], inplace=True) as f:
            for line in f:
                line = line.rstrip()
                line = re.sub(r"(\s+)hostname: (\S+).local", f"\\1hostname: \\2.{domain_name}", line)
                line = re.sub(r"(\s+)host: (\S+).local", f"\\1host: \\2.{domain_name}", line)
                line = re.sub(r"testing-toolkit.local", f"testing-toolkit.{domain_name}", line)
                print(line)

def turn_ttk_off(p,yaml):
    print("     <mojaloop-configure.py>  : WARNING turning TTK off for test/dev ")
    vf = p / "mojaloop" / "values.yaml"
    with open(vf) as f:
        data = yaml.load(f)
    data['ml-testing-toolkit']['enabled'] = False
    with open(vf, "w") as f:
        yaml.dump(data, f)

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
    script_path = Path( __file__ ).absolute()
    p = Path() / args.directory
    if args.verbose :
        print(f"     <mojaloop-configure.py>  : start ")
        print(f"     <mojaloop-configure.py>  : Processing helm charts in directory: [{args.directory}]")

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    # turn_ttk_off(p,yaml)
    if args.thirdparty:
        modify_values_for_thirdparty(p,yaml,args.verbose)
    if args.bulk:
        modify_values_for_bulk(p,yaml,args.verbose)  
    if args.domain_name :
         modify_values_for_dns_domain_name(p,args.domain_name,args.verbose)
    if args.verbose :
        print(f"     <mojaloop-configure.py>  : end ")

if __name__ == "__main__":
    main(sys.argv[1:])
