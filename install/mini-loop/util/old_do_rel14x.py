#!/usr/bin/env python3

"""
    This script modifies a copy of the Mojaloop helm repo (version 14) to 
    1) move dependencies in the requirements.yaml to Charts.yaml
    2) update the apiVersion for helm in all the Charts.yaml to 2 
    todo
    - updates the ingress if there is one with the ingress from bitnami
    - add the common dependency to each chart that already has an ingress
    - updates the values files for the new ingress settings 
    - ensure the updated values files have the correct hostname 
    - ensure the updated values files have the correct port number  

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

"""
update_key: recursively 
"""
def update_key(key, value, dictionary):
        for k, v in dictionary.items():
            if k == key:
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

def move_requirements_yaml (p,yaml):
    print("\n-- move requirements.yaml to charts -- " )
    # copy the dependencies from requirements.yaml to the Charts.yaml
    # update the helm api to apiVersion 2 
    #print(" ==> rel14x : copy dependencies from requirements.yaml to Charts.yaml")
    processed_cnt = 0 
    for rf in p.rglob('**/*requirements.yaml'):
        
        processed_cnt +=1
        rf_parent=rf.parent
        cf=rf.parent / 'Chart.yaml'
        #print(f"Processing requirements file {rf}")     
        with open(rf) as f:
            reqs_data = yaml.load(f)
            #print(reqs_data)
            try: 
                dlist = reqs_data['dependencies']
                # for i in range(len(dlist)): 
                #     if (dlist[i]['name'] in ["percona-xtradb-cluster","mysql"] ): 
                #         dlist[i]['name'] = "mysql"
                #         dlist[i]['version'] = 8.0
                #         dlist[i]['repository'] = "https://charts.bitnami.com/bitnami"
                #         dlist[i]['alias'] = "mysql"
                #         dlist[i]['condition'] = "mysql.enabled"

                # add the common library to dependencies
                common_lib_dict={ 
                    "name" : "common" , 
                    "repository" : "file://../common" , 
                    "version" : "2.0.0" }

                # some charts are 1 directory level lower 
                # so adjust the path the the common lib accordingly 
                if  rf_parent.parent != p : 
                   common_lib_dict['repository']="file://../../common"

                dlist.append(common_lib_dict)

                #print(f"Processing chart file {cf} ")
                #print("  ==> copy dependencies from requirements.yaml")
                with open(cf) as cfile: 
                    cfdata = yaml.load(cfile);
                    cfdata['dependencies']=dlist
            except Exception as e: 
                print(f" Exception {e} \n")        
                continue 
        with open(cf, "w") as cfile:
            yaml.dump(cfdata, cfile)

    print(f" ==> Deleting requirements.yaml files ")
    for rf in p.rglob('**/*requirements.yaml'):        
         #print(f"  ==> unlink/delete requirements: {rf}")    
         rf.unlink(missing_ok=True)
    print(f" ==> processed: [{processed_cnt}] requirements files ")

def update_helm_version (p,yaml):
    # update the helm api to apiVersion 2 
    print("\n-- update helm version to 2.0 -- ")
    processed_cnt = 0 
    for cf in p.rglob('**/*Chart.yaml'):
        processed_cnt +=1

        with open(cf) as f:
            cfdata = yaml.load(f)
            cfdata['apiVersion']="v2"

        with open(cf, "w") as f:
            yaml.dump(cfdata, f)

    print(f" ==> number of Charts files updated to v2.0 [{processed_cnt}] ")

def update_ingress(p, yaml,ports_array):
    print("-- update ingress -- ")
    # Copy the bitnami inspired ingress over the existing ingress
    bn_ingress_file = script_path.parent.parent / "./etc/bitnami/bn_ingress.yaml"
    #print(f"  ==> bn_ingress_file is : {bn_ingress_file}")
    # for each existing ingress, write the new ingress content over it
    for ingf in p.rglob('**/*ingress.yaml'): 
        #print(f" ==> copying new ingress to {ingf} ")
        shutil.copy(bn_ingress_file, ingf)

def get_sp(p,vf,ing_file,spa):
    # get the servicePort for the ingress file being processed
    # print(f"ingfile starts as {ing_file}")
    # print(f" relative path is {vf.relative_to(p)}")

    x_file = vf.relative_to(p)  # holds the ingress values file relative path
    ing_file = str(x_file.parent)
    print(f"ing_file is {ing_file } ingfile type is {type(ing_file)} ")
    if spa[ing_file]:
        print(f"found servicePort {spa[ing_file]} for ingress file {ing_file}  ")
        return spa[ing_file]

def update_values_for_ingress(p, yaml,spa):
    # copy in the bitnami template ingress values 
    print("-- update the values for ingress -- ")
    bivf = script_path.parent.parent / "./etc/bitnami/bn_ingress_values.yaml"

    origin_ingress_hostname=""
    origin_path=""
    vf_count=0
    ing_file_count = 0 
    service_port = ""
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/*values.yaml'):
        print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        
        # for each values file if there is an ingress we need to get the 
        # servicePort so we can set it in the updated / new values file 
        ing_file = vf.parent / 'templates' / 'ingress.yaml'
        #template_dir=vf.relative_to("templates")
        #print(f" templates_dir is {template_dir}")
        print(f"ing_file is {ing_file}")
        if ing_file.exists():
            ing_file_count += 1
            service_port=get_sp(p,vf,ing_file,spa)

        data=[]
        vf_count+=1
        # load the values file 
        with open(vf) as f:
            data = yaml.load(f)

        toplist = [] 
        ingress_parent_list = []
        hostname=""
        # get the top level yaml structures
        for x, value in lookup('ingress', data):
            lenx = len(x)
            #print(f"x is {x} and length if x fred is {len(x)} ")
            if lenx > 2:
                #print(f" parent is {x[lenx-2]}")
                ingress_parent_list.append(x[lenx-2])
                #print(f"parentlist full : {parent_list}")
            toplist = toplist + [x]
            

       # print(f"Examining the values.yaml  {vf.parent}/{vf.name}....") 
        # for i in toplist :
        #     print(f"toplist [{i[0]}]" ) 

        # for i in parent_list :
        #     print(f" parent_list [{i}]" ) 
        #print(f" toplist is [{i[0]}]")   
        # for each top level structure 
        # lookup its ingress if it has one 
        for i in ingress_parent_list:
            
            #print(f"values file: {vf}    toplist is [{i[0]}]")
            for x, value in lookup(i, data):
                print(f"processing parent {i} in values file {vf} and section {x} ")
                #print (f" x = {x}")
                # for some reason need to reset this data 
                # or it fails to insert more than once 
                with open(bivf) as f:
                    newdata = yaml.load(f)
                # update the bitnami template chart with the serviceport 
                newdata['servicePort'] = service_port
                for x1, value1 in lookup('ingress', value):
                    print("and found an ingress ")
                    # if isinstance(x1,list):
                    #     print("and the ingress is in a list")
                    #     print(f"x1 is {x1} and value1 is {value1}")
                    if value1.get('hosts'):
                        print("and found hosts entry")
                        hosts_section=value1['hosts']
                        if isinstance(hosts_section, list):
                            for i in hosts_section: 
                                hostname=i
                        if isinstance(hosts_section,dict):
                            for v in hosts_section.values():
                                hostname=v
                            if len(hostname) > 1 : 
                                print(f"Hostname is {hostname}")
                    #delete the current ingress values and insert new ones 
                    value1.clear()
                    update(value1,newdata)

        with open(vf, "w") as vfile:
            yaml.dump(data, vfile)

    print(f" number of values files updated is [{vf_count}]")
    print(f" number of ingress files catered for  is [{ing_file_count}]")



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
    
    service_ports_ary = {
        "transaction-requests-service" : "http",
        "mojaloop-simulator" : "outboundapi" ,
        "mojaloop-simulator" : "inboundapi" ,
        "mojaloop-simulator" : "testapi" ,
        "mojaloop-simulator" : "testapi" ,
        "eventstreamprocessor" : "http" ,
        "account-lookup-service/chart-service" : "http-api" ,
        "account-lookup-service/chart-admin" : "http-admin" ,
        "quoting-service" : "80" ,
        "centralsettlement/chart-service" : "80" , 
        "ml-testing-toolkit/chart-backend" : "5050" , 
        "ml-testing-toolkit/chart-frontend" : "6060" ,
        "centralledger/chart-handler-timeout" : "80" ,
        "centralledger/chart-service" : "80" ,
        "centralledger/chart-handler-transfer-get" : "80" ,
        "centralledger/chart-handler-admin-transfer" : "80" ,
        "centralledger/chart-handler-transfer-fulfil" : "80" ,
        "centralledger/chart-handler-transfer-position" : "80"  ,
        "centralledger/chart-handler-transfer-prepare" : "80" ,
        "simulator" : "80"  ,
        "centraleventprocessor" : "80" ,
        "emailnotifier" : "80" ,
        "ml-api-adapter/chart-service" : "80" ,
        "ml-api-adapter/chart-handler-notification" : "80" ,
        "ml-operator" : "4006" ,
        "centralkms" : "5432" ,
        "ml-testing-toolkit/chart-connection-manager-frontend" : "5060" ,
        "ml-testing-toolkit/chart-keycloak" : "80" ,
        "bulk-centralledger/chart-handler-bulk-transfer-get" : "80" ,
        "bulk-centralledger/chart-handler-bulk-transfer-processing" : "80" ,
        "bulk-centralledger/chart-handler-bulk-transfer-prepare" : "80" ,
        "bulk-centralledger/chart-handler-bulk-transfer-fulfil" : "80" ,
        "centralenduserregistry" : "3001" ,
        "als-oracle-pathfinder" : "80" ,
        "forensicloggingsidecar" : "5678" ,
        "bulk-api-adapter/chart-service" : "80" ,
        "bulk-api-adapter/chart-handler-notification" : "80" ,
        "thirdparty/chart-tp-api-svc" : "3008" ,
        "thirdparty/chart-consent-oracle" : "3000" ,
        "thirdparty/chart-auth-svc" : "4004" ,
        "ml-testing-toolkit/chart-connection-manager-backend" : "5061" 
    }
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


    # for k,v in service_ports_ary.items() : 
    #     print(f" the array is {k}:{v} ")
    # sys.exit(1)

    #ingress_cn = set_ingressclassname(args.kubernetes)
    #print (f"ingressclassname in main is {ingress_cn}")
    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    move_requirements_yaml(p,yaml) 
    update_helm_version(p,yaml)
    update_values_for_ingress(p,yaml,service_ports_ary)
    update_ingress(p,yaml,ports_array)  
 

if __name__ == "__main__":
    main(sys.argv[1:])