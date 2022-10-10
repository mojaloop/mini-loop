#!/usr/bin/env python3

"""
   fix the items comming from the PR review for feat 2352 (mainly by Miguel)
    author : Tom Daly 
    Date   : Oct 2022
"""

import fileinput
from operator import sub
import sys
import re
import argparse
from pathlib import Path
from fileinput import FileInput
import fileinput 
import json 
from ruamel.yaml import YAML
from ruamel.yaml import CommentedMap

data = None
script_path = Path( __file__ ).absolute()

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

def bump_chart_version(p,yaml):
    processed_cnt = 0 
    existing_version_dict={}
    new_version_dict={}
    # update the minor version number for each chart mojaloop chart
    # start by creating a dictionary of chart : versions
    for cf in p.rglob('**/*Chart.yaml'):
        processed_cnt += 1
        with open(cf) as f:
            cfdata = yaml.load(f)
        existing_version_dict[cf.parent]=cfdata['version'].strip()           

    for k,v in existing_version_dict.items():
        s = v.split('.')
        s[1]=str(int(s[1])+1)
        newval = '.'.join(s)
        new_version_dict[k]=newval 
        print(f" {k.name}  old version [{v}] incremented is [{newval}] path is {k}")
    
    # now reprocess all charts and update the version AND the dependencies versions 
    print(">>>>>>>>>>>>>>>>>  dependencies <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ")
    for cf in p.rglob('**/*Chart.yaml'):
        processed_cnt += 1
        with open(cf) as f:
            cfdata = yaml.load(f)
        
        # first the version 
        print(f" {cf.parent} version old {existing_version_dict[cf.parent]} new is {new_version_dict[cf.parent]}")
        cfdata['version']=new_version_dict[cf.parent]

        # get the chart name 
        #print(f"{cf.parent.name}")
        # now update dependencies
        dep_cnt=0
        for x, value in lookup('dependencies', cfdata):
            if(isinstance(value,list)) : 
                for dep in value:
                    print(f"    dependency : {dep['name']} ")
                    alt_chart_name=dep['repository'].rsplit('/',1)[-1]
                    #print(f" one of ours ? : {cf.parent/alt_chart_name}")
                    #print(f" dep is {dep['name']} and version is [{dep['version']}]")
                    # for chart_name ,version in new_version_dict.items():
                    #     p1=Path(chart_name)
                    #     if dep['name'] == p1.name:
                    #         print(f"     >> found chart name is {p1.name} oldv {dep['version']} new version {[version]}" )
                    #     elif (cf.parent / alt_chart_name) in new_version_dict.keys():  
                    #         print(f"     >> found alternate-chart-name {p1.name}  new version {version}")
                    #         print(f"         {cf.parent/alt_chart_name}  exists cf is {cf} and alt chart name is {alt_chart_name}")

                    if cf.parent.parent/alt_chart_name  in  new_version_dict.keys() :
                        print(f"     >> found in repo updated ML chart: {cf.parent.parent/alt_chart_name} oldv {dep['version']} new version {new_version_dict[cf.parent.parent/alt_chart_name]}" )
                        dep['version'] = new_version_dict[cf.parent.parent/alt_chart_name]    
                    elif cf.parent/alt_chart_name in new_version_dict.keys() :
                        print(f"     >> found repo updated ML chart: {cf.parent/alt_chart_name} oldv {dep['version']} new version {new_version_dict[cf.parent/alt_chart_name]}" )
                        dep['version'] == new_version_dict[cf.parent/alt_chart_name]
                    elif cf.parent/dep['name'] in  new_version_dict.keys() :
                        print(f"     >> found updated chart: {cf.parent/dep['name']} oldv {dep['version']} new version {new_version_dict[dep['name]']]}" )
                        dep['version'] == new_version_dict[dep['name]']]
            else: 
                print(f"dependency in {cf.parent} is not a list ==> investigate ")

        with open(cf, "w") as f:
            yaml.dump(cfdata, f)

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

    bump_chart_version(p,yaml)

 
if __name__ == "__main__":
    main(sys.argv[1:])