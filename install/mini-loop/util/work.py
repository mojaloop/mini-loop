#!/usr/bin/env python3

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

# def update(d, n):
#     if isinstance(n, CommentedMap):
#         print("\nupdate>> YES IS COMMENT MAP  ")
#         for k in n : 
#             print (f"update>> k = {k}")
#         for k in n:
#             print (f"update>> k = {k} d = {d}")
#             if k in d :
#                 print(f"update>> yes k = {k} is in d = {d}") 
#                 d[k] = update(d[k], n[k]) 
#             else:
#                  d[k]=n[k]
#                  print (f"update>>NO k is not in d n[k] is {n[k]} and d[] is {d}")
#                  print (f"AND  d[] is {d}")
            
#             if k in n.ca._items and n.ca._items[k][2] and \
#                n.ca._items[k][2].value.strip():
#                 print(f"=update>>> n.ca._items is {n.ca._items} and n.ca._items[k][2] is {n.ca._items[k][2]}")
#                 d.ca._items[k] = n.ca._items[k]  # copy non-empty comment
#     else:
#         print(f"\nupdate>> NOT COMMENT MAP d is {d} and n is {n} ")
#         #d.append(n)
#         d=n
#     return d

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

def insert(d, n):
    # print("TYRYING insert")
    if isinstance(n, CommentedMap):
        # print("YES is commented map")
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

# def update(d, n):
#     if isinstance(n, CommentedMap):
#         for k in n:
#             if k in d :
#                 d[k] = update(d[k], n[k])
#             else:
#                  n[k]
#             if k in n.ca._items and n.ca._items[k][2] and \
#                n.ca._items[k][2].value.strip():
#                 d.ca._items[k] = n.ca._items[k]  # copy non-empty comment
#     else:
#         d = n
#         print(f"update d is {d}")
#     return d

"""
update_key: recursively 
"""
def update_key(key, value, dictionary):
        for k, v in dictionary.items():
            if k == key:
                dictionary[key]=value
                #print(f">>>>> the dictionary got updated in the previous line : {dictionary[key]} ")
            elif isinstance(v, dict):
                for result in update_key(key, value, v):
                    yield result
            elif isinstance(v, list):
                for d in v:
                    if isinstance(d, dict):
                        for result in update_key(key, value, d):
                            yield result

##################################################
# main
##################################################
def main(argv) :

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096
 
    # 1 add the common dependencies chart to each chart in mojaloop
    # 2 update the API 
    # 3 add tomd@crosslake to maintainers 
    d1 = {"name":"common", "repository":"file://../common", "version":"2.0.0"}
    m1 = {"name" : "tom" , "email":"tomd@crosslaketech.com"}
    yaml_str1 = """
dependencies: 
  - name : common 
    repository : "file://../common" 
    version : 2.0.0  
"""
    yaml_str2 = """
dependencies:
  - name : common 
    repository : "file://../../common" 
    version : 2.0.0  
"""
    yaml_str3 = """
maintainers: 
  - name : Tom Daly 
    email : tomd@crosslaketech
"""
    yaml_str4a = """
apiVersion: v2
name: thirdparty
version: 2.0.0
description: Third Party API Support for Mojaloop
appVersion: 1.0.0
home: http://mojaloop.io
icon: http://mojaloop.io/images/logo.png
sources:
  -   https://github.com/mojaloop/mojaloop
  -   https://github.com/mojaloop/helm
  -   https://github.com/mojaloop/pisp-project
dependencies:
  - name: auth-svc
    version: 2.0.0
    repository: "file://./chart-auth-svc"
    condition: auth-svc.enabled
  - name: consent-oracle
    version: 0.2.0
    repository: "file://./chart-consent-oracle"
    condition: consent-oracle.enabled
maintainers:
  -   name: Lewis Daly
      email: lewisd@crosslaketech.com
"""
    yaml_str4 = """
apiVersion: v2
name: thirdparty
version: 2.0.0
description: Third Party API Support for Mojaloop
appVersion: 1.0.0
home: http://mojaloop.io
icon: http://mojaloop.io/images/logo.png
sources:
  -   https://github.com/mojaloop/mojaloop
  -   https://github.com/mojaloop/helm
  -   https://github.com/mojaloop/pisp-project
dependencies:
  - name: auth-svc
    version: 2.0.0
    repository: "file://./chart-auth-svc"
    condition: auth-svc.enabled
  - name: consent-oracle
    version: 0.2.0
    repository: "file://./chart-consent-oracle"
    condition: consent-oracle.enabled
"""

    maint_dict={"name" : "tom" , "email":"tomd@crosslaketech.com"}
    cy1 = yaml.load(yaml_str1)
    cy2 = yaml.load(yaml_str2)
    cy3 = yaml.load(yaml_str3)
    cy4 = yaml.load(yaml_str4)

    if (isinstance(cy1,list)):
        print("cy1 is a list")
    if  (isinstance(cy1,dict)):
        print("cy1 is a dictionary")
    print(f"{cy1['dependencies'][0]['repository']}")
    cy1['dependencies'][0]['repository'] = 'fred1'
    print(f"{cy1['dependencies'][0]['repository']}")
    if cy4.get("dependencies"): 
        print('DEPEND EXISTS')
        ## so dependencies exist => append common to them after 
        ## removing any existing common lib dependency which exists in thirdparty charts
        for x, value in lookup('dependencies', cy4):
            if(isinstance(value,list)) : 
                print("oh it is a list ")
                for i in value:
                    print(f"list i is {i}")
                    if i['name'] == "common":
                        print("try deleting it  ")
                        value.remove(i)
                value.append(d1)
            
                #insert(value,d1)
            else: 
                printf("WARNING: chart.yaml file not as expected ")    
    else: 
        print ("trying to add keys when there are not any dependencies)")
        # no existing dependencies in chart.yaml
        #cy4['dependencies']=cy2
        #insert(cy4,cy2)
        update(cy4,cy1)
    if cy4.get("maintainers"): 
        for x, value in lookup('maintainers', cy4):
            if(isinstance(value,list)) : 
                print("oh maintainers is a list ")
                for i in value:
                    print(f"list i is {i}")
                #value.append(m1)
                insert(value,m1)
            else:
                printf("WARNING: chart.yaml file not as expected ")
    else : 
        # currently no maintainers in chart.yaml
        update(cy4,cy3)
    # if there were no existing dependencies and/or maintainers 
    print(f"cy2 is a {type(cy2)}")
    #update(cy4,cy2)
    #update(cy4,cy3)
    yaml.dump(cy4,sys.stdout)



 

if __name__ == "__main__":
    main(sys.argv[1:])