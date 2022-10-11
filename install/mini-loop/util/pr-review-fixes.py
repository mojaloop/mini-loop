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
                    # remove any railing space from repository 
                    
                    alt_chart_name=(dep['repository'].rstrip('/')).rsplit('/',1)[-1]
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
                        print(f"     >> found in repo updated ML chart: {cf.parent.parent/alt_chart_name} oldv {dep['version']} new version {new_version_dict[cf.parent.parent/alt_chart_name]} parent/parent" )
                        dep['version'] = new_version_dict[cf.parent.parent/alt_chart_name]    
                    elif cf.parent/alt_chart_name in new_version_dict.keys() :
                        print(f"     >> found repo updated ML chart: {cf.parent/alt_chart_name} oldv {dep['version']} new version {new_version_dict[cf.parent/alt_chart_name]} parent" )
                        dep['version'] = new_version_dict[cf.parent/alt_chart_name]
                    # elif cf.parent/dep['name'] in  new_version_dict.keys() :
                    #     print(f"     >> found updated chart: {cf.parent/dep['name']} oldv {dep['version']} new version {new_version_dict[dep['name]']]}" )
                    #     dep['version'] = new_version_dict[dep['name]']]
            else: 
                print(f"dependency in {cf.parent} is not a list ==> investigate ")

        with open(cf, "w") as f:
            yaml.dump(cfdata, f)

def fix_helpers_remove_ing_logic(p,ceplist):
    ## remove unused / redundant ingress templates ##
    print("-- removing unused ingress templates from _helper.tpl files  -- ")
    processed_cnt = 0 
    excluded_cnt = 0 
    updates_cnt = 0 
    nlines=7
    n=0
    for hf in p.rglob('**/*_helpers.tpl'):
        if hf.parent.parent in ceplist or hf.parent in ceplist : 
            print(f" Excluding helper files  {hf.parent.parent/hf} or {hf.parent/hf}")
            excluded_cnt +=1 
        else: 
            processed_cnt +=1 
            with open(str(hf)) as f:
                lines = f.readlines()

            with open(str(hf), "w") as f:
                print(f"  processing : {hf.parent/hf}")
                printem = True
                for l in lines:
                    #l = l.rstrip()
                    if re.search(r".apiVersion.Ingress\" -\}\}",l):
                        updates_cnt += 1 
                        printem=False
                        n=0
                    if printem: 
                        f.writelines(l)
                        n+=1 
                    if n > nlines: 
                        printem = True

                processed_cnt += 1    
    print(f" total number of _helpers.tpl files processed [{processed_cnt}]")
    print(f" total number of _helpers.tpl files excluded [{excluded_cnt}]")
    print(f" total number of ingress templates removed [{updates_cnt}]")

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

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    chart_names_exclude_list = [
        "finance-portal-settlement-management",
        "finance-portal",
        "thirdparty",
        "thirdparty/chart-tp-api-svc",
        "thirdparty/chart-consent-oracle",
        "thirdparty/chart-auth-svc",
        "mojaloop-simulator",
        "keycloak",
        "monitoring",
        "monitoring/promfana",
        "monitoring/elk",
        "ml-testing-toolkit",
        "ml-testing-toolkit/chart-keycloak",
        "ml-testing-toolkit/chart-backend",
        "ml-testing-toolkit/chart-frontend",
        "ml-testing-toolkit/chart-connection-manager-backend",
        "ml-testing-toolkit/chart-connection-manager-frontend"
    ]

    chart_path_exclude_list = []
    for c in chart_names_exclude_list : 
        chart_path_exclude_list.append(p / c)

    bump_chart_version(p,yaml)
    fix_helpers_remove_ing_logic(p,chart_path_exclude_list)

 
if __name__ == "__main__":
    main(sys.argv[1:])