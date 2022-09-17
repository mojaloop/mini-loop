#!/usr/bin/env python3

"""
    This script modifies a copy of the Mojaloop helm repo (version 14) to 
    - move dependencies in the requirements.yaml to Charts.yaml
    - update the apiVersion for helm in all the Charts.yaml to 2 
    - updates the ingress if there is one with the ingress from bitnami
    - add the common dependency to each chart that already has an ingress
    todo
    - updates the values files for the new ingress settings 
    - ensure the updated values files have the correct hostname 
    - ensure the updated values files have the correct port number  
    - update maintainers in chart.yaml to include tomd@crosslaketech
    - bug: not all lower directory chart.yaml files are being updated
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

def update_requirements_files (p, yaml):
    # yeah I know I update he requirements only to move em and 
    # delete em ... but I had this working code to get rid
    # of percona and doing it seprately lets me test separately 
    # with and without db changes 
    print(" update requirements.yaml replace deprecated percona chart with current mysql")
    for rf in p.rglob('**/*requirements.yaml'):
        with open(rf) as f:
            reqs_data = yaml.load(f)
            #print(reqs_data)
        try: 
            dlist = reqs_data['dependencies']
            for i in range(len(dlist)): 
                if (dlist[i]['name'] in ["percona-xtradb-cluster","mysql"] ): 
                    dlist[i]['name'] = "mysql"
                    dlist[i]['version'] = 8.0
                    dlist[i]['repository'] = "https://charts.bitnami.com/bitnami"
                    dlist[i]['alias'] = "mysql"
                    dlist[i]['condition'] = "mysql.enabled"

                # if (dlist[i]['name'] == "mongodb"):
                #     print(f"old was: {dlist[i]}")
                #     dlist[i]['version'] = "11.1.7"
                #     dlist[i]['repository'] = "file://../mongodb"
                #     print(f"new is: {dlist[i]}")
        except Exception:
            continue 

        with open(rf, "w") as f:
            yaml.dump(reqs_data, f)      

def move_requirements_yaml (p,yaml):
    print("\n-- move requirements.yaml to charts -- " )
    # copy the dependencies from requirements.yaml to the Charts.yaml
    # update the helm api to apiVersion 2 
    processed_cnt = 0 
    for rf in p.rglob('**/*requirements.yaml'):    
        processed_cnt +=1
        rf_parent=rf.parent
        cf=rf.parent / 'Chart.yaml'
        print(f"  Processing requirements file {rf}")     
        with open(rf) as f:
            reqs_data = yaml.load(f)
            #print(reqs_data)
            try: 
                dlist = reqs_data['dependencies']
                with open(cf) as cfile: 
                    cfdata = yaml.load(cfile);
                cfdata['dependencies']=dlist
            except Exception as e: 
                print(f" Exception {e} with file {rf} \n")        
                continue 
        # yaml.dump(cfdata,sys.stdout)
        with open(cf, "w") as cfile:
            yaml.dump(cfdata, cfile)
    print(f" ==> processed: [{processed_cnt}] requirements files ")
    print(f" ==> Deleting requirements.yaml files ")
    for rf in p.rglob('**/*requirements.yaml'):        
        #print(f"  ==> unlink/delete requirements: {rf}")    
        rf.unlink(missing_ok=True)
    print(f" ==> Deleting requirements.lock files ")  
    for rf in p.rglob('**/*requirements.lock'):           
        rf.unlink(missing_ok=True)   

    


def update_all_helm_charts_yaml (p,yaml): 
    # 1 add the common dependencies chart to each chart in mojaloop
    # 2 update the API 
    # 3 add tomd@crosslake to maintainers 
    yaml_str1 = """
dependencies: 
  - name : common 
    repository : "file://../common" 
    version : 2.0.0  
"""
    yaml_str2 = """
maintainers: 
  - name : Tom Daly 
    email : tomd@crosslaketech
"""
    print("\n-- updating charts.yaml update vers, add dependencies, maintainers -- ")
    d1 = {"name":"common", "repository":"file://../common", "version":"2.0.0"}
    m1 = {"name" : "tom" , "email":"tomd@crosslaketech.com"}
    dy1 = yaml.load(yaml_str1)
    my1 = yaml.load(yaml_str2)

    processed_cnt = 0 
    for cf in p.rglob('**/*Chart.yaml'):
        if  cf.parent.parent != p : 
            d1['repository']="file://../../common"
            dy1['dependencies'][0]['repository'] = "file://../../common"
        else: 
            d1['repository']="file://../common"
            dy1['dependencies'][0]['repository'] = "file://../common"
        processed_cnt +=1
        with open(cf) as f:
            cfdata = yaml.load(f)
        if cfdata.get("dependencies"): 
            ## so dependencies exist => append common to them after 
            ## removing any existing common lib dependency which exists in thirdparty charts
            # print("YES DEPS EXIST")
            for x, value in lookup('dependencies', cfdata):
                if(isinstance(value,list)) : 
                    for i in value:
                        if i['name'] == "common":
                            value.remove(i)
                    insert(value,d1)        
                    #value.append(d1)    
                else: 
                    printf(f"WARNING: {cf.parent/cf} chart.yaml file not as expected ")  
        else: 
            # print("NO DEPS EXIST")
            # no existing dependencies in chart.yaml
            update(cfdata,dy1)
        if cfdata.get("maintainers"): 
            for x, value in lookup('maintainers', cfdata):
                if(isinstance(value,list)) : 
                    #value.append(m1)
                    insert(value,m1)
                else:
                    printf(f"WARNING: {cf.parent/cf} chart.yaml file not as expected ")    
        else : 
            # currently no maintainers in chart.yaml
            update(cfdata,my1)

        #yaml.dump(cfdata, sys.stdout)
        with open(cf, "w") as f:
            yaml.dump(cfdata, f)
    print(f" ==> processed: [{processed_cnt}] chart.yaml files ")

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
    if spa[ing_file]:
        print(f"    - found servicePort {spa[ing_file]} for ingress file {ing_file}  ")
        return spa[ing_file]

def get_sp_new(x,value,spa):
    if len(x) >= 2 : 
        parent_node = x[len(x)-2]
        print(f"    >parent node is {parent_node}")
        try : 
            if spa[parent_node]:
                print(f"found servicePort {spa[parent_node]} from ingress_parent  ")
                return spa[parent_node] 
        except: 
            return [] 

def update_values_for_ingress(p, yaml,spa):
    # copy in the bitnami template ingress values 
    print("-- update the values for ingress -- ")
    bivf = script_path.parent.parent / "./etc/bitnami/bn_ingress_values.yaml"

    origin_ingress_hostname=""
    origin_path=""
    vf_count=0
    ing_file_count = 0 
    ing_sections_count=0
    service_port = ""
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/*values.yaml'):
        print(f"===> Processing file < {vf.parent}/{vf.name} > ")
        
        # for each values file if there is an ingress we need to get the 
        # servicePort so we can set it in the updated / new values file 
        ing_file = vf.parent / 'templates' / 'ingress.yaml'
        #template_dir=vf.relative_to("templates")
        #print(f" templates_dir is {template_dir}")
        print(f"    ing_file is {ing_file}")


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
            if ing_file.exists():
                ing_file_count += 1
                service_port=get_sp(p,vf,ing_file,spa)
            else : 
                service_port=get_sp_new(x,value,spa) 
            if value.get('enabled'):
                enabled_value=value['enabled']
            else:
                 enabled_value="false"
            #print("    enabled") if enabled_value=="true" else 0 
            print(f"    enabled_value is {enabled_value}")
            if value.get('hosts'):
                ing_sections_count +=1 
                hosts_section=value['hosts']
                if isinstance(hosts_section, list):
                    for i in hosts_section: 
                        hostname=i
                if isinstance(hosts_section,dict):
                    for v in hosts_section.values():
                        hostname=v
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
            # NOTE for the moment it looks like externalpath
            # is usd just as path for many of the old ingress.yaml
            # so I think this can remain unset
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
            value.clear()
            with open(bivf) as f:
                newdata = yaml.load(f)
            update(value,newdata)
            value['hostname'] = hostname
            if len(path_value) > 0 : 
                value['path'] = path_value
            # if len(epath_value): >0 : 
            #     value['extraPaths'] = epath_value 
            value['servicePort'] = service_port 

        with open(vf, "w") as vfile:
            yaml.dump(data, vfile)

    print(f" number of values files updated is [{vf_count}]")
    print(f" number of ingress files catered for  is [{ing_file_count}]")
    print(f" number of individual ingress values sections updated [{ing_sections_count}]")

def update_json_files (p) : 
    # update all the references to the old ingress values
    # to do server.host ??
    print("-- update the json files for new ingress  -- ")
    processed_cnt = 0 
    updates_cnt = 0 
    cnt = 0 
    for jf in p.rglob('**/*.json'):
        #print(f" processing json file {jf.parent/jf}")
        with FileInput(files=[jf], inplace=True) as f:
            for line in f:
                line = line.rstrip() 
                line, cnt = re.subn(r"Values.ingress.hosts.api",r"Values.ingress.hostname",line) 
                updates_cnt += cnt  
                #print(f"cnt is {cnt}", file=sys.stderr)
                print(line)
            processed_cnt +=1
    print(f" number of json files processed [{processed_cnt}]")
    print(f" number of updates made [{updates_cnt}]")
       

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
        "account-lookup-service" : 4002,
        "account-lookup-service/chart-admin" : "http-admin" ,
        "account-lookup-service-admin" : "http-admin",
        "quoting-service" : 80 ,
        "centralsettlement/chart-service" : 80, 
        "ml-testing-toolkit/chart-backend" : 5050 , 
        "ml-testing-toolkit/chart-frontend" : 6060 ,
        "centralledger/chart-handler-timeout" : 80 ,
        "centralledger/chart-service" : 80 ,
        "centralledger/chart-handler-transfer-get" : 80 ,
        "centralledger/chart-handler-admin-transfer" : 80 ,
        "centralledger/chart-handler-transfer-fulfil" : 80 ,
        "centralledger/chart-handler-transfer-position" : 80  ,
        "centralledger/chart-handler-transfer-prepare" : 80 ,
        "simulator" : 80  ,
        "centraleventprocessor" : 80 ,
        "emailnotifier" : 80 ,
        "ml-api-adapter/chart-service" : 80 ,
        "ml-api-adapter/chart-handler-notification" : 80 ,
        "ml-operator" : "4006" ,
        "centralkms" : "5432" ,
        "ml-testing-toolkit/chart-connection-manager-frontend" : "5060" ,
        "ml-testing-toolkit/chart-keycloak" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-get" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-processing" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-prepare" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-fulfil" : 80 ,
        "centralenduserregistry" : "3001" ,
        "als-oracle-pathfinder" : 80 ,
        "forensicloggingsidecar" : "5678" ,
        "bulk-api-adapter/chart-service" : 80 ,
        "bulk-api-adapter/chart-handler-notification" : 80 ,
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

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    update_json_files(p)
    update_requirements_files(p, yaml) 
    move_requirements_yaml(p,yaml) 
    update_all_helm_charts_yaml(p,yaml)
    update_values_for_ingress(p,yaml,service_ports_ary)
    update_ingress(p,yaml,ports_array)  
 
if __name__ == "__main__":
    main(sys.argv[1:])