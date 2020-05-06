# Mini-Loop
Opinionated Mojaloop 'in a box' using Vagrant, K8s and Helm

```bash
git clone https://github.com/tdaly61/laptop-mojo.git
cd laptop-mojo/vbox-deploy
vagrant up
```

## Overview

Mini-loop is a simple, opinonated 'out of the box' installation of [Mojaloop](https://mojaloop.io) for test and demonstration purposes. The goal is to make it easy and reliable to deploy Mojaloop both locally or in a cloud environment.

This project essentially automates the instructions for the linux installation in the mojaloop documentation at https://mojaloop.io/documentation/deployment-guide/local-setup-linux.html#mojaloop-setup-for-linux-ubuntu.

There are however some minor variations from these onboarding docs, such as using helm3 charts and enabling kubernetes version 1.18.  See [#1070-helm3](https://github.com/mojaloop/project/issues/1070) and [#219-kubernetes-version](https://github.com/mojaloop/helm/issues/219) for more deatils.


## Description / Approach

Using Hashicorp Vagrant, a VirtualBox Ubnutu VM or Google Cloud VM is created and all of the components required to run mojaloop are automatically installed and configured into this VM. One the VM is booted the mojaloop helm chart is deployed and the mojaloop kubernetes pods and services will be created. The user or test scripts can then access the VM and then a small number of scripts are pre-loaded under the shared /vagrant directory to:
1. run the postman collections to load test data 
2. execute the mojaloop postman/newman based Golden_Path test collections against this mojaloop installation using localhost.  

## Prerequisites 

### Common 
 - [HashiCorp `vagrant`](https://www.vagrantup.com)
 - `git` 

### VirtualBox Deployment (Local)
- [Virtualbox and accompanying Guest Additions](https://www.virtualbox.org/wiki/Downloads)

> On MacOS, you can use homebrew:

```bash
brew cask install virtualbox
```

[todo: verify versions... brew version at the time of writing is still `6.1.4`, which seems to be broken]

- [HashiCorp `vagrant`](https://www.vagrantup.com)
- min 8GB ram available
- min 64GB storage available
- broadband internet connection (for downloading initial linux images in the form of vagrant boxes, if your internet connection is slow you may want to consider using the google cloud deployment instead)

### Google Cloud Deployment 
- Google Cloud SDK and SDK credentials (https://cloud.google.com/sdk/docs/downloads-versioned-archives)

## Setup

### Local (Virtualbox)
```bash
git clone https://github.com/tdaly61/laptop-mojo.git
cd laptop-mojo/vbox-deploy
vagrant up #creates the virtualbox VM, boots and configures the OS
```

### Google Cloud Services
Assuming vagrant is installed and running and the google cloud SDK is downloaded and you have setup SDK keys and ssh keys for google compute.

```bash
git clone https://github.com/tdaly61/laptop-mojo.git
cd laptop-mojo/gcs-deploy

# edit the Vagrantfile and enter correct values for
#   - google.google_project_id = "<your project_id>"
#   - google.google_json_key_location = "<path to your service account key>"
#   - override.ssh.username = "<your_username>"
#   - override.ssh.private_key_path = "~/.ssh/google_compute_engine"

# TODO: add notes about setting up an account and getting a service account key
# TODO: where is this VM located? How do we configure this?

vagrant up --provider=google #loads the vagrant google-plugin and creates the google cloud VM , boots and configures the OS
```

[TODO: fix issue when running for first time]:

```
Installed the plugin 'vagrant-google (2.5.0)'!
The provider 'google' could not be found, but was requested to
back the machine 'default'. Please use a provider that exists.

Vagrant knows about the following providers: docker, hyperv, virtualbox
```

subsequent runs seem to work however

## Run the postman setup steps

```bash
vagant ssh # to login as user you specified in the override.ssh.username = above
sudo su - 

su - vagrant #mojaloop is deployed and owned by the vagrant user
cd /vagrant

# wait for all mojaloop pods to reach "running" state.  use `kubectl get pods` to check and note this might take a little while 
./scripts/setupLocal.sh # use postman to install test data
./scripts/runGoldenPathLocal.sh #run the mojaloop GoldenPath postman collection tests
```

[todo: this failed on GCS, I think postman wasn't cloned properly, or perhaps it should be `/vagrant` instead of `/home/vagrant`

```bash
vagrant@i-2020050613-5ea755ad:/vagrant$ ./scripts/setupLocal.sh
-== Creating Hub Accounts ==-
error: ENOENT: no such file or directory, open '/home/vagrant/postman/environments/Mojaloop-Local.postman_environment.json'

-== Onboarding PayerFSP ==-
error: ENOENT: no such file or directory, open '/home/vagrant/postman/OSS-New-Deployment-FSP-Setup.postman_collection.json'

-== Onboarding PayeeFSP ==-
error: ENOENT: no such file or directory, open '/home/vagrant/postman/environments/Mojaloop-Local.postman_environment.json'

```

]

[todo: now getting 503s for those above calls]




## Notes:

Once the fixes for mojaloop to enable helm3 and kubernetes version 1.17 and 1.18  have been put back into the mojaloop repo and helm repository, the access to vessels-tech repo will no longer be needed and the mojaloop-install-local.sh script can be eliminated by moving that functionality into the Vagrant file. This would also mean that data loading could be done from the Vagrantfile and so instructions simplify to running "vagrant up"

As at April 27th 2020 the Golden_Path collection throws errors on a number of the transfers and this needs further debugging.

this is tested so far with:
- OSX VirtualBox host
- google cloud service
- Virtualbox 6.1.6
- ubuntu 1804 guest (via hashicorp published vagrant box)
- vagrant  2.2.7


## TODO:
- Switch out k8s for k3s internally
- Integrate postman tests as part of the vagrant up command. This would require the environment to be a little smarter about waiting for 
- Demonstrate a CI/CD workflow for automated release testing