# mojaloop automated laptop install
27th April 2020

Project to automate the installation of the mojaloop application (mojaloop.io) for test and demonstration purposes. The goal is to make it  easy and reliable to deploy and test mojaloop application either to the desktop or to google cloud. This project essentially automates the instructions for the linux installation in the mojaloop documentation at https://mojaloop.io/documentation/deployment-guide/local-setup-linux.html#mojaloop-setup-for-linux-ubuntu.  There are however some minor variations from these onboarding docs, such as using helm3 charts and enabling kubernetes version 1.18.  See https://github.com/mojaloop/project/issues/1070 (helm3) and https://github.com/mojaloop/helm/issues/219 (kubernetes version)


## Description / approach
Using hashicorp vagrant, a VirtualBox linux VM or Google Cloud VM is created and all of the components required to run mojaloop are automatically installed and configured into this VM. One the VM is booted the mojaloop helm chart is deployed and the mojaloop kubernetes pods and services will be created.  The user or test scripts can then access the VM and then a small number of scripts are pre-loaded under the shared /vagrant directory to :-
- run the postman collections to load test data 
- execute the mojaloop postman/newman based Golden_Path test collections against this mojaloop installation using localhost.  

## prerequisites 
### Common 
 - HashiCorp Vagrant (vagrant.com)
 - git 

### VirtualBox deployment 
- Virtualbox and accompanying Guest Additions (virtualbox.org)
- HashiCorp Vagrant (vagrant.com)
- min 8GB ram available
- min 64GB storage available
- broadband internet connection (for downloading initial linux images in the form of vagrant boxes, if your internet connection is slow you may want to consider using the google cloud deployment instead)

### Google Cloud Deployment 
- google cloud SDK and SDK credentials (see https://cloud.google.com/sdk/docs/downloads-versioned-archives)

## Setup and run instructions : VirtualBox
Assuming that virtualbox (including guest additions) is installed 
- `git clone https://github.com/tdaly61/laptop-mojo.git `
- `cd laptop-mojo/vbox-deploy`
- `vagrant up` [creates the virtualbox VM, boots and configures the OS ]
- `vagant ssh` [to login as user vagrant to the new VM once it is running ]
- `cd /vagrant` [ change to /vagrant inside the VM ]
- wait for all mojaloop pods to reach "running" state.  use `kubectl get pods` to check and note this might take a little while 
- `./scripts/setupLocal.sh` [uses postman/newman to install test data ]
- `./scripts/runGoldenPathLocal.sh` [to run the mojaloop GoldenPath postman collection / tests ]


## Setup and run instructions : Google Cloud Services
Assuming vagrant is installed and running and the google cloud SDK is downloaded and you have setup SDK keys and ssh keys for google compute.
- `git clone https://github.com/tdaly61/laptop-mojo.git `
- `cd laptop-mojo/gcs-deploy`
- edit the Vagrantfile and enter correct values for :- 
    - override.ssh.username = "tdaly"
    - override.ssh.private_key_path = "~/.ssh/google_compute_engine"
- `vagrant up --provider=google` [loads the vagrant google-plugin and creates the google cloud VM , boots and configures the OS ]
- `vagant ssh` [to login as user you specified in the override.ssh.username = above  ]
- sudo su -   
- su - vagrant [ mojaloop is deployed and owned by the vagrant user ] 
- `cd /vagrant` [ change to /vagrant inside the VM ]
- wait for all mojaloop pods to reach "running" state.  use `kubectl get pods` to check and note this might take a little while 
- `./scripts/setupLocal.sh` [uses postman/newman to install test data ]
- `./scripts/runGoldenPathLocal.sh` [to run the mojaloop GoldenPath postman collection / tests ]

- `vagrant up` or  [creates the virtualbox VM, boots and configures the OS ]


## Notes : 
Once the fixes for mojaloop to enable helm3 and kubernetes version 1.17 and 1.18  have been put back into the mojaloop repo and helm repository, the access to vessels-tech repo will no longer be needed and the mojaloop-install-local.sh script can be eliminated by moving that functionality into the Vagrant file. This would also mean that data loading could be done from the Vagrantfile and so instructions simplify to running "vagrant up"

As at April 27th 2020 the Golden_Path collection throws errors on a number of the transfers and this needs further debugging.

this is tested so far with :-
- OSX VirtualBox host
- google cloud service
- Virtualbox 6.1.6
- ubuntu 1804 guest (via hashicorp published vagrant box)
- vagrant  2.2.7
