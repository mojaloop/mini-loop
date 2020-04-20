# mojaloop automated laptop install
20th April 2020

Project to automate the installation of the mojaloop application (mojaloop.io) for test and demonstration purposes. The goal is to make it extremely easy and reliable to deploy and test mojaloop application on the desktop. This project essentially automates the instructions for the linux installation in the mojaloop documentation at https://mojaloop.io/documentation/deployment-guide/local-setup-linux.html#mojaloop-setup-for-linux-ubuntu.  There are however some minor variations from these onboarding docs, such as using helm3 charts and enabling kubernetes version 1.18.  See https://github.com/mojaloop/project/issues/1070 (helm3) and https://github.com/mojaloop/helm/issues/219 (kubernetes version)


## Description / approach
Using vagrant, a VirtualBox linux VM is created and  all of the components required to run mojaloop are automatically  installed and configured. A small number of very small scripts are provided to:-
- install mojaloop in this configured VM using helm3
- run the postman collections to load test data 
- execute the mojaloop postman/newman based Golden_Path test collections against this mojaloop installation using localhost.  

## prerequisites 
- Virtualbox and accompanying Guest Additions (virtualbox.org)
- HashiCorp Vagrant (vagrant.com)
- git 
- min 8GB ram available
- min 64GB storage available
- broadband internet connection (for downloading initial linux images in the form of vagrant boxes)
- access to the vessels-tech github repo ( https://github.com/vessels-tech/helm.git)
Please see below for details of the environment(s) that this has been tested on. 

## Instructions 
Assuming that virtualbox (including guest additions) and vagrant are installed and running.
- `git clone https://github.com/tdaly61/laptop-mojo.git `
- `cd laptop-mojo`
- `vagrant up` [creates the virtualbox VM, boots and configures the OS ]
- `vagant ssh` [to login as user vagrant to the new VM once it is running ]
- `cd /vagrant` [ change to /vagrant inside the VM ]
- `./scripts/mojaloop-install-local.sh` [ installs mojaloop for kubernetes 1.18 from vessels-tech]
- wait for all mojaloop pods to reach "running" state.  use `kubectl get pods` to check and note this might take a little while 
- `./scripts/setupLocal.sh` [uses postman/newman to install test data ]
- `./scripts/runGoldenPathLocal.sh` [to run the mojaloop GoldenPath postman collection / tests ]

## Notes : 
Once the fixes for mojaloop to enable helm3 and kubernetes version 1.17 and 1.18  have been put back into the mojaloop repo and helm repository, the access to vessels-tech repo will no longer be needed and the mojaloop-install-local.sh script can be eliminated by moving that functionality into the Vagrant file. This would also mean that data loading could be done from the Vagrantfile and so instructions simplify to running "vagrant up"

As at April 20th 2020 the Golden_Path collection throws errors on a number of the transfers and this needs further debugging.

this is tested so far with :-
- OSX VirtualBox host
- Virtualbox 6.1.6
- ubuntu 1804 guest (via hashicorp published vagrant box)
- vagrant  2.2.7