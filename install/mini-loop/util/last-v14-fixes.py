#!/usr/bin/env python3

"""
    Fix the .json formatting 
    Fix the comment indenting in the values files for the feat/2352 API updates
    author : Tom Daly 
    Date   : Sept 2022
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
import json 

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


 
def tidy_values_files(p, yaml):
    # copy in the bitnami template ingress values 
    print("-- tidy up the values files  -- ")
   
    json_cnt = 0
    line_cnt = 0 
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/*mojaloop/*values.yaml'):
        outfile = open("/tmp/out.txt","w")
        with open(str(vf)) as f:
            lines = f.readlines()

        for l in lines : 
            line_cnt += 1 
            #l = l.rstrip()
            if re.search(r".json:",l): 
                jstart=re.search(r".json:",l).start()
                if re.search(r"#",l[0:jstart]):
                    # then the .json is commented out 
                    outfile.writelines(l)
                    #continue
                else:
                    print(f"===> Processing file < {vf.parent}/{vf.name} > ") 
                    json_cnt += 1 
                    # #print(f"jstart is {jstart} and contents of line at jstart is {l[jstart:50]}")
                    # #jstartpos=re.search(r"{\"",l[jstart:]).start()
                    # jstartpos=re.search(r"{\"",l[jstart:]).start()
                    # l=l.substr(r"{\",l)
                    # print(f"jstartpos is {jstartpos} at line number {line_cnt} json looks like  {l[jstartpos:50]}")
                    x = l.find("{")
                    print(f" start {x}, line num is {line_cnt} and substr is {l[x:40]}")
                    #print ()
                    try : 
                        data = json.loads(l[x:])
                        l=json.dumps(data, indent=4)
                        outfile.write("fred")
                        outfile.writelines(l)
                        #print(json.dumps(data, indent=4))
                        #print(l)
                    except Exception as e : 
                        print(f"Error with json : in file {vf.parent}/{vf.name}  start {x}, line num is {line_cnt} and substr is {l[x:40]}")
                        #outfile.writelines(l)
            else: 
                outfile.writelines(l)
        outfile.close()
    print(f" total number of .json sections  [{json_cnt}]")

def fix_ingress_values_indents(p,yaml):
    delete_list = [
           "# Secrets must be manually created in the namespace",
          "# - secretName: chart-example-tls",
          "#   hosts:",
          "#     - chart-example.local"
    ]
    line_cnt = 0 
    ing_section_cnt = 0 
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/*values.yaml'):
        outfile = open("/tmp/out.txt","w")
        with open(str(vf)) as f:
            lines = f.readlines()

        ing_section=False
        for l in lines : 
            line_cnt += 1 
            if re.search(r"ingress:",l):
                ing_section=True
                ing_section_cnt += 1 
                # how many spaces before the ingress
                indent1=re.search(r"ingress:",l).start()
                print(f"ingress found at line {line_cnt} and col {indent1} ing_section is {ing_section}")
            elif re.search(r"className: \"nginx\"",l):
                ing_section=False

            if ing_section: 
                #fix the indentation 
                x = l.find(r"##")
                #print (f"hello ing_section is {ing_section} and x is {x}")
                if x > -1 : 
                    #new_spaces = indent1+2
                    spaces_str="                  "
                    l1 = re.sub(r"^.*##",spaces_str[0:indent1+2]+"##",l) 
                    #print(f"comment found at col {x} but ingress is at col {indent1} ")
                    outfile.writelines(l1)
                else:
                    outfile.writelines(l)
            else: 
                found=False
                for item in delete_list: 
                    if l.find(item) > -1:
                        found=True 
                if not found : 
                    outfile.writelines(l)
        outfile.close()
    print(f" total number of ingress sections  [{ing_section_cnt}]")         

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

    # s1 = "production.json: { then some text"
    # print(f"s1[5:] is {s1[5:]}")

    #tidy_values_files(p,yaml)
    fix_ingress_values_indents(p,yaml)
 
if __name__ == "__main__":
    main(sys.argv[1:])