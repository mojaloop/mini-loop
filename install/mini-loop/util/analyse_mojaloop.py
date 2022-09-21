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

def print_ingress_yaml_files (p, yaml): 
     for ingf in p.rglob('**/*ingress.yaml'): 
        print(f"ingress: {ingf.parent}/{ingf}")

def get_sp(p,vf,ing_file,spa):
    # get the servicePort for the ingress file being processed
    # print(f"ingfile starts as {ing_file}")
    # print(f" relative path is {vf.relative_to(p)}")

    x_file = vf.relative_to(p)  # holds the ingress values file relative path
    ing_file = str(x_file.parent)
    #print(f"ing_file is {ing_file } ingfile type is {type(ing_file)} ")
    if spa[ing_file]:
        print(f"    found servicePort {spa[ing_file]} for ingress file {ing_file}  ")
        return spa[ing_file]

def ingress_print_toplevel_details(p,yaml):
   for vf in p.rglob('**/mojaloop/*values.yaml'):
        print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        data=[]
        # extraHosts = []
        # load the values file 
        with open(vf) as f:
            data = yaml.load(f)
            for x, value in lookup('ingress', data):
                if value.get('enabled'):
                    enabled_value=value['enabled']
                else:
                    enabled_value="false"
                if len(x) >= 2 : 
                    parent_node = x[len(x)-2]
                #print(f" ingress for {parent_node} is {enabled_value}")
                if value.get('hosts') is not None : 
                    hosts_section=value['hosts']
                    if isinstance(hosts_section, list):
                        print(f"parent_sec : {parent_node} is a list ")
                        if len(hosts_section) > 1 : 
                            n = 0 
                            for h in hosts_section:
                                n += 1 
                                #print(f"    DEBUG5 list and need extra hosts for {h} and count = {n}")
                        # print(f"DEBUG: hosts section is list ")
                        for i in hosts_section: 
                            if ( isinstance(i,dict)):
                                hostname = i['host']
                            else:
                                #print(f"          DEBUG8 type of host sub section is {type(i)}")
                                hostname=i
                            
                    if isinstance(hosts_section,dict):
                        print(f"parent_sec : {parent_node} is a dict ")
                        extraHosts = []
                        n = 0 
                        for v,z in hosts_section.items():
                            if n == 0 : 
                                print(f"n = 0 and hostname == {z}")
                                hostname=z
                            else : 
                                print(f"n = {n} and z = {z}")
                                extraHosts.append(z['host']) 
                            n += 1 
                            if len(extraHosts) > 0: 
                                print(f"      DEBUG6: hosts section is dict {hosts_section} extraHosts = {extraHosts}")

                    if len(hostname) > 0 : 
                            print(f"    hostname is {hostname}")
                if value.get('path'):
                    paths_section=value['path']
                    if isinstance(p, list):
                        for i in paths_section: 
                            path_value=i
                    if isinstance(paths_section,dict):
                        for v in paths_section.values():
                            path_value=v
                    if isinstance(paths_section,str):
                        path_value = paths_section
                    if len(path_value) > 0 : 
                            print(f"    path is {path_value}")


def dig_out_values_for_ingress(p, yaml,spa):
    # copy in the bitnami template ingress values 
    print("-- dig out the  values for ingress -- ")
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
        if ing_file.exists():
            print(f"    ing_file is {ing_file}")
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
        path_value=""
        epath_value=""
        enabled_value=""
        # get the top level yaml structures
        for x, value in lookup('ingress', data):
            if value.get('enabled'):
                enabled_value=value['enabled']
            else:
                 enabled_value="false"
            #print("    enabled") if enabled_value=="true" else 0 
            print(f"    enabled_value is {enabled_value}")
            if value.get('hostname'):
                hosts_section=value['hostname']
                if isinstance(hosts_section, list):
                    for i in hosts_section: 
                        hostname=i
                if isinstance(hosts_section,dict):
                    for v in hosts_section.values():
                        hostname=v
                if len(hostname) >= 1 : 
                        print(f"    hostname is {hostname}")
            if value.get('path'):
                paths_section=value['path']
                if isinstance(p, list):
                    for i in paths_section: 
                        path_value=i
                if isinstance(paths_section,dict):
                    for v in paths_section.values():
                        path_value=v
                if isinstance(paths_section,str):
                    path_value = paths_section
                if len(path_value) >= 1 : 
                        print(f"    path is {path_value}")
            # if value.get('externalPath'):
            #     epaths_section=value['externalPath']
            #     if isinstance(p, list):
            #         for i in epaths_section: 
            #             epath_value=i
            #     if isinstance(epaths_section,dict):
            #         for v in epaths_section.values():
            #             epath_value=v
            #     if isinstance(epaths_section,str):
            #         epath_value = epaths_section
            #     if len(epath_value) > 0 : 
            #             print(f"    path is {epath_value}")

    print(f"\n  number of values files examined is [{vf_count}]")
    print(f"  number of ingress files examined  is [{ing_file_count}]")



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

    print_ingress_yaml_files(p,yaml)
    dig_out_values_for_ingress(p,yaml,service_ports_ary)
    # update_ingress(p,yaml,ports_array)  
 

if __name__ == "__main__":
    main(sys.argv[1:])