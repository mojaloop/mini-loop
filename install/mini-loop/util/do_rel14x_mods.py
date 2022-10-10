#!/usr/bin/env python3

"""
    This script modifies a copy of the Mojaloop helm repo (version 14) to 
    - move dependencies in the requirements.yaml to Charts.yaml
    - update the apiVersion for helm in all the Charts.yaml to 2 
    - if the chart has an ingress and it is not on the exclusion list => 
                      update the ingress if there is one with the ingress from bitnami
    - ensure the updated values files have the correct hostname for the ingress
    - ensure the updated values files have the correct port number for the ingress 
    - add the common dependency to each chart that already has an ingress
    - updates the values files for the new ingress settings 
    - update maintainers in chart.yaml to include tomd@crosslaketech
    - _helper.tpl updated to use correct ingress APIs 
    - update _helpers.tpl to remove ingress version logic completely 
    - verify that charts that have ingress names other than exactly ingress.yaml do not 
      have these ingress copied over i.e. thirdparty charts with 2 ingress.
    - update config/default.json files for values.ingress.api.host or similar to use .Values.ingress.hostname 

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


def update_helpers_files(p):
    processed_cnt = 0 
    updates_cnt = 0 
    for hf in p.rglob('**/*_helpers.tpl'):
        with FileInput(files=[hf], inplace=True) as f:
            for line in f:
                line = line.rstrip()
                #replace networking v1beta1 
                line,cnt = re.subn(r"networking.k8s.io/v1beta1", r"networking.k8s.io/v1", line)
                updates_cnt += cnt 
                line,cnt = re.subn(r"extensions/v1beta1", r"networking.k8s.io/v1", line )
                updates_cnt += cnt  
                print(line)
            processed_cnt += 1    
    print(f" total number of _helpers.tpl files processed [{processed_cnt}]")
    print(f" total number of updates made to _helpers.tpl files [{updates_cnt}]")

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
        #print(f"  Processing requirements file {rf}")     
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
    print(f"Deleting requirements.yaml files ")
    for rf in p.rglob('**/*requirements.yaml'):        
        #print(f"  ==> unlink/delete requirements: {rf}")    
        rf.unlink(missing_ok=True)
    print(f" ==> Deleting requirements.lock files ")  
    for rf in p.rglob('**/*requirements.lock'):           
        rf.unlink(missing_ok=True)   
    print(f"total number of requirements files  processed: [{processed_cnt}] ")

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
    yaml_str1a = """
dependencies: 
  - name : common 
    repository : "https://docs.mojaloop.io/charts/repo"
    tags:
      - moja-common
    version : 2.0.0  
"""

    yaml_str2 = """
maintainers: 
  - name : Tom Daly 
    email : tomd@crosslaketech.com
"""

    print("\n-- updating charts.yaml update vers, add dependencies, maintainers -- ")
    d1 = {"name":"common", "repository":"https://docs.mojaloop.io/charts/repo", "version":"2.0.0" , "tags":['moja-common']}
    m1 = {"name" : "Tom Daly" , "email":"tomd@crosslaketech.com"}
    dy1 = yaml.load(yaml_str1a)
    my1 = yaml.load(yaml_str2)

    processed_cnt = 0 
    for cf in p.rglob('**/*Chart.yaml'):
        processed_cnt += 1
        # if  cf.parent.parent != p : 
        #     d1['repository']="file://../../common"
        #     dy1['dependencies'][0]['repository'] = "file://../../common"
        # else: 
        #     d1['repository']="file://../common"
        #     dy1['dependencies'][0]['repository'] = "file://../common"
        # processed_cnt +=1
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
        
        ## update apiVersion
        cfdata['apiVersion']="v2"

        #yaml.dump(cfdata, sys.stdout)
        with open(cf, "w") as f:
            yaml.dump(cfdata, f)
    print(f" ==> total number of chart.yaml files processed  [{processed_cnt}] ")

def update_ingress(p, yaml,ports_array,ceplist):
    print("-- update ingress -- ")
    processed_cnt = 0 
    # Copy the bitnami inspired ingress over the existing ingress
    # Note the ingress name must be ingress.yaml other ingress names are not over written yet
    bn_ingress_file = script_path.parent.parent / "./etc/bitnami/bn_ingress.yaml"
    #print(f"ceplist is {ceplist}")
    for ingf in p.rglob('**/ingress.yaml'): 
        #print(f" parent is {ingf.parent}, parent.parent is {ingf.parent.parent} ")
        if ingf.parent.parent in ceplist: 
            print(f"Excluding chart {ingf.parent.parent/ingf}")
        else : 
            print(f" copying to {ingf.parent/ingf}")
            with open(ingf,'r') as f: 
                path_count=0
                host_count=0
                for line in f:
                    line=line.rstrip()
                    if re.search("path:", line ):
                        path_count += 1 
                    if re.search("path:", line ):
                        host_count += 1 
                        # if re.search("range", line):
                        #     #print(f" line is {line} for ingress {ingf.parent/ingf}")
                if path_count > 1 : 
                    print(f" path_count is {path_count} for ingress {ingf.parent/ingf}")
                if host_count > 1 : 
                    print(f" host_count is {host_count} for ingress {ingf.parent/ingf}")
               
    #print(f"  ==> bn_ingress_file is : {bn_ingress_file}")
    # for each existing ingress, write the new ingress content over it

    for ingf in p.rglob('**/ingress.yaml'): 
        if ingf.parent.parent in ceplist:
            print(f"Excluding chart {ingf.parent.parent/ingf}")
        else : 
            #print(f" DEBUG2 copying new ingress to {ingf} ")
            shutil.copy(bn_ingress_file, ingf)
            processed_cnt += 1
    print(f" total number of ingress files copied in [{processed_cnt}]")

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
        if parent_node : 
            print(f"    >parent node is {parent_node}")
        try : 
            if spa[parent_node]:
                print(f"      found servicePort {spa[parent_node]} from ingress_parent  ")
                return spa[parent_node] 
        except: 
            print(f"    WARNING1 : can't find serviceport for parent_node {parent_node} in ports array")
            return

def update_values_for_ingress(p, yaml,spa,ceplist,ynel,pary,set_enabled=False):
    # copy in the bitnami template ingress values 
    print("-- update the values for ingress -- ")
    bivf = script_path.parent.parent / "./etc/bitnami/bn_ingress_values.yaml"

    origin_ingress_hostname=""
    origin_path=""
    vf_count=0
    ing_file_count = 0 
    ing_sections_count=0
    service_port = ""
    print(f"ceplist is {ceplist}")
    #for vf in p.rglob('*account*/**/*values.yaml'):
    for vf in p.rglob('**/*values.yaml'):
        # we exclude the values files of the charts where we are not unifying the ingress
        print(f"vf.parent.parent is {vf.parent.parent}")
        if vf.parent.parent in ceplist or vf.parent in ceplist : 
            print(f"DEBUG5 Excluding values files updating for {vf.parent.parent/vf}")
        else : 
            print(f"===> Processing file < {vf.parent}/{vf.name} > ")   
            # for each values file if there is an ingress we need to get the 
            # servicePort so we can set it in the updated / new values file 
            ing_file = vf.parent / 'templates' / 'ingress.yaml'
            print(f"    ing_file is {ing_file}")
            data=[]
            vf_count+=1
            # load the values file 
            with open(vf) as f:
                data = yaml.load(f)

            parent_node=""
            hostname=""
            path_value=""
            epath_value=""
            enabled_value=""
            # get the top level yaml structures
            for x, value in lookup('ingress', data):
                if (len(x)) >=2:
                    parent_node = x[len(x)-2]
                if parent_node in ynel:
                    print(f" excluding parent node {parent_node}")
                else: 
                    if ing_file.exists():
                        ing_file_count += 1
                        service_port=get_sp(p,vf,ing_file,spa)
                        print("    service_port set from ingress file ")
                    else : 
                        service_port=get_sp_new(x,value,spa) 
                    #if len(service_port) < 2  :
                    if not service_port: 
                        print(f"     WARNING service_port is not set") 
                    if value.get('enabled'):
                        enabled_value=value['enabled']
                    else:
                        enabled_value="false"
                    #print(f"    enabled_value is {enabled_value}")
                    if value.get('hosts') is not None : 
                        ing_sections_count +=1 
                        hosts_section=value['hosts']
                        if isinstance(hosts_section, list):
                            if len(hosts_section) > 1 : 
                                n = 0 
                                for h in hosts_section:
                                    n += 1 
                                    print(f"      DEBUG4 need extra hosts for {h} count = {n} x = {x}")
                            for i in hosts_section: 
                                if ( isinstance(i,dict)):
                                    hostname = i['host']
                                else:
                                    #print(f"DEBUG1 type of host sub section is {type(i)}")
                                    hostname=i
                        if isinstance(hosts_section,dict):
                                #print(f"parent_sec : {parent_node} is a dict ")
                                extraHosts = []
                                n = 0 
                                for v,z in hosts_section.items():
                                    #print(f" v = {v} and z = {z}")
                                    if n == 0 : 
                                        #print(f"n = 0 and hostname == {z}")
                                        if (isinstance(z,dict)):
                                            if z.get('host'): 
                                                hostname = z['host']
                                        else: 
                                            hostname = z
                                    else : 
                                        #print(f"n = {n} and z = {z}")
                                        extraHosts.append(z['host']) 
                                    n += 1 
                                    if len(extraHosts) > 0: 
                                        print(f"  FOUND EXTRA HOSTS hosts section is dict {hosts_section} extraHosts = {extraHosts}")
                                    
                        if len(hostname) > 0 : 
                            print(f"      hostname is {hostname}")
                        else : 
                            print("     WARNING HOSTNAME NOT FOUND")
                    # NOTE: turns out that path is almost always / so we can just default to that 
                    # and pick up discrepencies during testing 

                    # if value.get('path'):
                    #     paths_section=value['path']
                    #     if isinstance(p, list):
                    #         for i in paths_section: 
                    #             path_value=i
                    #     if isinstance(paths_section,dict):
                    #         for v in paths_section.values():
                    #             path_value=v
                    #     if isinstance(paths_section,str):
                    #         path_value = paths_section
                    #     if len(path_value) > 0 : 
                    #         print(f"    path is {path_value}")
                    #     else : 
                    #         print(" WARNING PATH NOT FOUND ")
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
                    #value['enabled'] = enabled_value
                    value['hostname'] = hostname
                    if len(extraHosts) > 0 : 
                        value['extraHosts'] = extraHosts
                    if len(path_value) > 0 : 
                        value['path'] = path_value
                    # if len(epath_value): >0 : 
                    #     value['extraPaths'] = epath_value  
                    if (isinstance(service_port,str)):
                        print(f"DEBUG7 servicePort is str ")
                        if pary.get(service_port):
                            service_port=pary[service_port]
                            print(f"DEBUG8 servicePort is in ports_array ")
                        else :
                            service_port=int(service_port)
                    value['servicePort'] = service_port 
                    print(f"DEBUG6 servicePort is {service_port}")

            with open(vf, "w") as vfile:
                yaml.dump(data, vfile)

    print(f" total number of values files updated is [{vf_count}]")
    print(f" total number of ingress files catered for  is [{ing_file_count}]")
    print(f" total number of individual ingress values sections updated [{ing_sections_count}]")

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
    print(f" total number of json files processed [{processed_cnt}]")
    print(f" total number of updates made to json files [{updates_cnt}]")
       

#### in place modifications 
def in_place_update_ingress_values_files(p, yaml,spa,ceplist,pary,set_enabled=False):
    for vf in ceplist:
        ing_file=vf/"templates"/"ingress.yaml"
        if ing_file.exists():
            print(f"ingress file to update in place is {ing_file.parent/ing_file}")
            with FileInput(files=[ing_file], inplace=True) as f:
                for line in f:
                    line = line.rstrip()
                    if re.search("path:", line ):
                        line_dup = line
                        line_dup = re.sub(r"- path:.*$", r"  pathType: ImplementationSpecific", line_dup)
                        print(line)
                        print(line_dup)
                    elif re.search("serviceName:", line ):
                        line_dup=line
                        line_dup = re.sub(r"serviceName:.*$", r"service:", line_dup)
                        print(line_dup)
                        line=re.sub(r"serviceName:", r"  name:", line)
                        print(line)
                    elif re.search("servicePort:", line ):                        
                        line_dup = line 
                        line_dup=re.sub(r"servicePort:.*$", r"  port:", line_dup)
                        line = re.sub(r"servicePort: ", r"    number: ", line)
                        # need to replace port names with numbers 
                        for pname , pnum  in pary.items() : 
                            #print(f"DEBUG9 servicePort before replacement is {line}")
                            line = re.sub(f"number: .*{pname}.*$", f"number: {pnum}", line )
                        print(line_dup)
                        print(line)
                    elif re.search("ingressClassName" , line ):
                        # skip any ingressClassname already set => we can re-run program without issue 
                        continue
                    elif re.search("spec:" , line ):        
                        print(line)
                        print("  ingressClassName: nginx") 
                    else :  
                        print(line)

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
        "mojaloop-simulator" : 3003 ,
        "mojaloop-simulator" : 3003 ,
        "eventstreamprocessor" : 80 ,
        "account-lookup-service/chart-service" : 4002 ,
        "account-lookup-service" : 4002,
        "account-lookup-service/chart-admin" : 4002 ,
        "account-lookup-service-admin" : 4002,
        "quoting-service" : 80 ,
        "centralsettlement/chart-service" : 80, 
        "centralsettlement-service" : 80 ,
        "centralsettlement-handler-rules" : 80,
        "centralsettlement-handler-deferredsettlement" : 80,
        "centralsettlement-handler-grosssettlement" : 80 , 
        "ml-testing-toolkit/chart-backend" : 5050 , 
        "ml-testing-toolkit/chart-frontend" : 6060 ,
        "centralledger/chart-handler-timeout" : 80 ,
        "centralledger-handler-timeout" : 80, 
        "centralledger/chart-service" : 80 ,
        "centralledger-service" : 80, 
        "centralledger/chart-handler-transfer-get" : 80 ,
        "centralledger-handler-transfer-get" : 80, 
        "centralledger/chart-handler-admin-transfer" : 80 ,
        "centralledger-handler-admin-transfer" : 80, 
        "centralledger/chart-handler-transfer-fulfil" : 80 ,
        "centralledger-handler-transfer-fulfil" : 80 ,
        "centralledger/chart-handler-transfer-position" : 80  ,
        "centralledger-handler-transfer-position" : 80, 
        "centralledger/chart-handler-transfer-prepare" : 80 ,
        "centralledger-handler-transfer-prepare" : 80,
        "simulator" : 80  ,
        "centraleventprocessor" : 80 ,
        "emailnotifier" : 80 ,
        "ml-api-adapter/chart-service" : 80 ,
        "ml-api-adapter-service" : 80 ,
        "ml-api-adapter/chart-handler-notification" : 80 ,
        "ml-api-adapter-handler-notification" : 80 ,
        "ml-operator" : 4006 ,
        "centralkms" : 5432 ,
        "ml-testing-toolkit/chart-connection-manager-frontend" : 5060 ,
        "ml-testing-toolkit/chart-keycloak" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-get" : 80 ,
        "cl-handler-bulk-transfer-get" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-processing" : 80 ,
        "cl-handler-bulk-transfer-processing" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-prepare" : 80 ,
        "cl-handler-bulk-transfer-prepare" : 80 ,
        "bulk-centralledger/chart-handler-bulk-transfer-fulfil" : 80 ,
        "cl-handler-bulk-transfer-fulfil" : 80 ,
        "centralenduserregistry" : 3001 ,
        "als-oracle-pathfinder" : 80 ,
        "forensicloggingsidecar" : 5678 ,
        "bulk-api-adapter/chart-service" : 80 ,
        "bulk-api-adapter-service" : 80 ,
        "bulk-api-adapter/chart-handler-notification" : 80 ,
        "bulk-api-adapter-handler-notification" : 80 , 
        "thirdparty/chart-tp-api-svc" : 3008 ,
        "tp-api-svc": 3008, 
        "thirdparty/chart-consent-oracle" : 3000 ,
        "consent-oracle" : 3000,
        "thirdparty/chart-auth-svc" : 4004 ,
        "auth-svc" : 4004,
        "ml-testing-toolkit/chart-connection-manager-backend" : 5061 , 
        "ml-testing-toolkit-backend" : 5061, 
        "ml-testing-toolkit-frontend" : 80 , 
        # assume port 80 for sims 
        "payerfsp" : 80,
        "payeefsp" : 80,
        "testfsp1" : 80,
        "testfsp2" : 80,
        "testfsp3" : 80,
        "testfsp4" : 80,
        "defaults" : 80
    }

    ports_array  = {
        "simapi" : 3000,
        "reportapi" : 3002,
        "testapi" : 3003,
        "https" : 80,
        "http"  : 80,
        "http-admin" : 4001,
        "http-api"  : 4002,
        "mysql" : 3306,
        "mongodb" : 27017,
        "inboundapi" : "{{ $config.config.schemeAdapter.env.INBOUND_LISTEN_PORT }}",
        "outboundapi" : "{{ $config.config.schemeAdapter.env.OUTBOUND_LISTEN_PORT }}",
        "ingress.servicePort" : 80
    }

    # which nodes in the top level yaml file to exclude unifying
    yaml_node_exclude_list = [
        "chart-tp-api-svc",
        "chart-consent-oracle",
        "chart-auth-svc",
        "chart-keycloak",
        "ml-testing-toolkit-backend",
        "ml-testing-toolkit-frontend",
        "alertmanager",
        "server",
        "pushgateway",
        "grafana",
        "elasticsearch",
        "kibana",
        "apm-server",
        "keycloak",
        "payerfsp",
        "payeefsp",
        "testfsp1",
        "testfsp2",
        "testfsp3",
        "testfsp4",
        "defaults",
        "mojaloop-simulator"
    ]

    # the charts and ingress in this list will not be unified to the new ingress standard
    # rather just updated to the new ingress API in-place.
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
        "ml-testing-toolkit/chart-keycloak",
        "ml-testing-toolkit/chart-backend",
        "ml-testing-toolkit/chart-frontend",
        "ml-testing-toolkit/chart-connection-manager-backend",
        "ml-testing-toolkit/chart-connection-manager-frontend"
    ]

    p = Path() / args.directory
    print(f"Processing helm charts in directory: [{args.directory}]")

    chart_path_exclude_list = []
    for c in chart_names_exclude_list : 
        chart_path_exclude_list.append(p / c)

    yaml = YAML()
    yaml.allow_duplicate_keys = True
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=6, offset=2)
    yaml.width = 4096

    update_helpers_files(p)
    update_json_files(p)
    #update_requirements_files(p, yaml) 
    move_requirements_yaml(p,yaml) 
    update_all_helm_charts_yaml(p,yaml)
    update_values_for_ingress(p,yaml,service_ports_ary,chart_path_exclude_list,yaml_node_exclude_list,ports_array,set_enabled=True)
    update_ingress(p,yaml,ports_array,chart_path_exclude_list)  
    in_place_update_ingress_values_files(p,yaml,service_ports_ary,chart_path_exclude_list,ports_array,set_enabled=True)
 
if __name__ == "__main__":
    main(sys.argv[1:])