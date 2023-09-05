# mini-loop vnext-alpha - install Mojaloop vNext alpha release (using kubernetes v1.26 - 1.27 with rancher k3s or microk8s) 

## Description 
mini-loop vnext-alpha is a simple, scripted/automated installer for Mojaloop vNext. For details on the Mojaloop vNext version please refer to the Mojaloop reference architecture available from (http://mojaloop.io). mini-loop vNext is designed to enable demo, test, training and development of the Mojaloop vNext switch and its associated environment. 

The goal is to make it realistic, easy, quick, scriptable and cost effective to deploy Mojaloop vNext in a variety of local or cloud environments. 
- realistic: running a full kubernetes stack , so you can do real-world tests
- easy : you only need to run 1 or 2 simple shell scripts
- quick : With a sufficiently configured linux instance and internet connection it should be possible to deploy and configure Mojaloop vNext in approx 15 mins or less.
- scriptable: the scripts are easily callable from other scripts or from CI/CD tools
- cost effective : uses minimal resources, everything you need to test Mojaloop vNext and nothing you don't need

Example environments include:-
- an x86_64 laptop or server running ubuntu 20 or 22 
- an x86_64 laptop or server running ubuntu 20 or 22 as a guest VM (say using virtualbox , prarallels, qemu or similar) 
- an appropriately sized x86_64 ubuntu 20 or 22 cloud instance running in any of the major cloud vendors (hint about 6GB without logging and elastic search turned on and 8GB otherwise )
 

# Installation instructions 

## Example #1 K3s, kubernetes 1.26 
Assuming you have an x86_64 environment running Ubuntu release 22 and are logged in as a non-root user (e.g. mluser)
```bash
login as mluser                                                       # login as an existing non-root user e.g. mluser
git clone --branch vnext-alpha-1 https://github.com/mojaloop/mini-loop.git    # clone the mini-loop scripts
sudo ./mini-loop/scripts/k8s-install.sh -m install -k k3s -v 1.26     # install and configure k3s 
source $HOME/.bashrc                                                  # or logout/log in again to set env
./mini-loop/scripts/vnext-alpha-install.sh -m install_ml                    # configure and deploy vNext
```

## Example #2 Microk8s, kubernetes 1.27
Assuming you have an x86_64 environment running Ubuntu release 20 or 22 and are logged in as a non-root user (e.g. mluser)
```bash
login as mluser                                                         # login as an existing non-root user e.g. mluser
git clone --branch vnext-alpha-1 https://github.com/mojaloop/mini-loop.git      # clone the mini-loop scripts
sudo ./mini-loop/scripts/k8s-install.sh -m install -k microk8s -v 1.27  # install and configure microk8s 
source $HOME/.bashrc                                                    # or logout/log in again to set env
./mini-loop/scripts/vnext-alpha-install.sh -m install_ml                      # configure and deploy vNext
```

# Accessing Mojaloop from a laptop 
The mini-loop scripts add the required host names to the 127.0.0.1 entry in the /etc/hosts of the "install system" i.e. the system where Mojaloop is deployed.  To access Mojaloop from beyond this system it is necessary to:- 
1. ensure that http / port 80 is accessible on the install system.  For instance if mini-loop has installed Mojaloop onto a VM in the cloud then it will be necessary to ensure that the cloud network security rules allow inbound traffic on port 80 to that VM.
2. add the hosts listed below to an entry for the external/public ip address of that install system in the /etc/hosts file of the laptop you are using. **todo add in the instructions for windows 10**

 For example if Mojaloop vNext is installed on a cloud VM with a public IP of 192.168.56.100  Then add an entry to your laptop's /etc/hosts similar to ...
```
192.168.56.100  vnextadmin elasticsearch.local kibana.local mongohost.local mongo-express.local redpanda-console.local fspiop.local bluebank.local greenbank.local bluebank-specapi.local greenbank-specapi.local
```
You should now be able to browse or curl to Mojaloop vNext admin url using  http://vnextadmin you can also access the deloyed instances of the Mojaloop testing toolkit at http://bluebank.local and http://greenbank.local

Note: see [below](#modify-hosts-file-on-windows-10) for intructions on updating the hosts file on your windows 10 laptop 

## Prerequisites 
- a running x86_64 ubuntu 22 environment (ubuntu 20 is ok but less tested for vnext-alpha)
- root user or sudo access
- non-root user (with bash shell)
- git installed (usually installed by default on Ubuntu 22) 
- min 6GB ram available  (8GB if you turn on elastic search and logging )
- min 30GB storage available (50GB plus is preferred)
- broadband internet connection from the ubuntu OS (for downloading helm charts and container images )

## Notes for mini-loop vnext-alpha 
- Mojaloop code is developed to be deployable in a robust, highly available and highly secure fashion *BUT* the mini-loop deployment focusses on simplicity and hence is not deploying Mojaloop in a highly secure, highly available fashion.  The mini-loop deployment of Mojaloop is *NOT* intended for production purposes rather it enables:
  - trial: users new, expert and in-between to quickly run and access Mojaloop and its various features
  - test : enables the Mojaloop community do realistic testing of Mojaloop across a broad range of settings 
           From DFSPs working on integrating with Mojaloop to the Mojaloop core team where mini-loop is being used to enhance the quality of the Mojalop switch.
  - education: a powerful education "on-ramp" especially when used in conjunction with the testing toolkit and the Mojaloop tutorial.
  - demonstrations: an excellent platform for a range of Mojaloop demonstrations. This is due to the cost-effect and light-weight yet realistic (e.g. uses kubernetes) nature of the Mojaloop deployment 
  - simplicity: anyone can read the simple bash scripts and understand how kubernetes is being installed and Mojaloop is being configured and deployed
- the mini-loop scripts output messages to help guide your deployment , please pay attention to these messages
- .log and .err files are written to /tmp by default (but this is configurable) 
- each of the scripts has a -h flag to show parameters and give examples of how to use and customise
- The the scripts are intended to provide a starting point, for further customisation. For instance it should be easy for the user to add extra nodes to the kubernetes cluster or as mentioned above to modify the mojaloop configuration etc.
- please note that the installation adds the /etc/hosts entries for the endpoints configured in the $ETC_DIR/miniloop_values.yaml file if you use different values you will likely have to adjust the /etc/hosts endpoints and if you configure a domain name then /etc/hosts entries are not needed instead you need your domain name to resolve. 
- the mini-loop/install/mini-loop/util directory contains a few scripts and debugging tools that I find useful , I am not really maintaining these but you might find some of them handy as I do. 

## known issues with mini-loop vnext-alpha
1. mini-loop vnext-alpha has only been tested properly with ubuntu 20 and 22 
2. The format of the logfiles is a bit of a mess at the moment, it is intended to tidy these up so that mini-loop scripts can be used very (cost) effectively in CI/CD pipelines across multiple configurations of Mojaloop and its environment such as kubernetes releases etc. 
3. the  -d option allows the user to configure the DNS domain name for their Mojaloop services. It is not as fully tested as other mini-loop features and I need to add some documentation on how to use and critically test this (note this is important for Mifos integration )
4. if we deploy with -o and then come and redeploy without -f or -o then thirdparty and bulk will again be deployed and this might not be intended 
5. the endpoint testing is not implemented yet and so it is possible for the install to "look ok" but to not function correctly. Normally if you get messages from the scripts that indicate everyting was ok, then it probably is , but testing endpoints and other checks before giving the all-good messages needs improving and will in future releases.

## modify hosts file on windows 10
1. open Notepad
2. Right click on Notepad and then Run as Administrator.
3. allow this app to make changes to your device? type Yes.
4. In Notepad, choose File then Open C:\Windows\System32\drivers\etc\hosts or click the address bar at the top and paste in the path and choose Enter.  If you don’t see the host file in the /etc directory then select All files from the File name: drop-down list, then click on the hosts file.
5. Add the IP from your VM or system and then add a host from the list of required hosts (see example below)
6. flush your DNS cache. Click the Windows button and search command prompt, in the command prompt:-
```
    ipconfig /flushdns
```

Note you can only have one host per line so on windows 10 your hosts file should look something like: 
```
192.168.56.100 vnextadmin 
192.168.56.100 elasticsearch.local 
192.168.56.100 mongohost.local 
192.168.56.100 mongo-express.local 
192.168.56.100 redpanda-console.local 
192.168.56.100 fspiop.local 
192.168.56.100 bluebank.local 
192.168.56.100 greenbank.local 
192.168.56.100 bluebank-specapi.local 
192.168.56.100 greenbank-specapi.local
```

## FAQ
1. Q: I think it installed ok , how to I test ?  
A: see the section on accessing Mojaloop from a laptop and try accessing the http://vnextadmin.local or the URL for the domain-name you installed with. 

2. Q: what about windows ?
A: The best way to run on a windows laptop is to provision an Ubuntu 20 or 22 virtual machine using one of the popular Hypervisors available today (HyperV, VirtualBox, UTM etc) 
