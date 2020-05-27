# Mini-loop
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

Using Hashicorp Vagrant, a VirtualBox Ubnutu VM or Google Cloud VM is created and all of the components required to run mojaloop are automatically installed and configured into this VM. Once the VM is booted the mojaloop helm chart is deployed and the mojaloop kubernetes pods and services created, the mini-loop configuration automatically runs the /vagrant/scripts/setup-local-env.sh script to load test data into the mojaloop application and then executes the mojaloop postman/newman based Golden_Path test collections against this mojaloop installation using localhost.  

Once the golden_path tests have completed, users can interact with the installation. Refer to the instructions below on logging into the VM and running a transfer. 

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

> Note: you may be able to install guest additions directly onto Vagrant with [vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest). We haven't tested this ourselves, but give it a shot and let us know if it works!


- [HashiCorp `vagrant`](https://www.vagrantup.com)
- min 6GB ram available  (8GB recommended) 
- min 64GB storage available
- broadband internet connection (for downloading initial linux images in the form of vagrant boxes, if your internet connection is slow you may want to consider using the google cloud deployment instead)

### Google Cloud Deployment 
- vagrant Google plugin
``` 
vagrant plugin install vagrant-google 
```
- Google Cloud SDK (https://cloud.google.com/sdk/docs/downloads-versioned-archives and https://cloud.google.com/sdk/install )
- Google Cloud Service accounts and service account key ( https://cloud.google.com/iam/docs/creating-managing-service-account-keys ) 
- Google Cloud ssh keys established (https://www.youtube.com/watch?v=JGcW1QdEQGs) 

## Setup

### Local (Virtualbox)
```bash
git clone https://github.com/tdaly61/laptop-mojo.git
cd laptop-mojo/vbox-deploy
vagrant up #creates the virtualbox VM, boots and configures the OS
```

### Google Cloud Services
Assuming vagrant is installed and running and the google cloud prerequisites as detailed above established.

```bash
git clone https://github.com/tdaly61/laptop-mojo.git
cd laptop-mojo/gcs-deploy
```

edit the Vagrantfile and enter correct values for
  - google.google_project_id = "<your_project_id>"  # e.g. my_project_id
  - google.google_json_key_location = "<path_to_your_service_account_key>"  # e.g." ~/my_project_id.json" 
  - override.ssh.username = "<your_username>" # look in the service account key to find this e.g. in ~/my_project_id.json
  - override.ssh.private_key_path = "<your_private_ssh_key>"  # e.g. "~/.ssh/google_compute_engine"

```
vagrant up --provider=google # uses the vagrant google-plugin and creates the google cloud VM , boots and configures the OS
```

## Accessing the VM and running a sample transfer
ensure your current directory is the directory from which you ran "vagrant up" 
```bash
vagant ssh # to login as user you specified in the override.ssh.username = above
sudo su - 

su - vagrant #mojaloop is deployed and owned by the vagrant user
cd /vagrant

./scripts/mini-loop-create-transfer.sh 
```

## Notes:
- For VirtualBox you can examine the VM using the GUI console.
- For GCS you can find the VM using the Google Cloud Console (https://console.cloud.google.com) via Navigation menu -> compute engine -> vm instances.  The Navigation menu is the 3 horizontal lines to the left of the  "Google Cloud Platform" banner. 
- for GCS if you are using a "passphrase" on your ssh key , vagrant up will get stuck waiting for SSH-KEY, if this happens then use ssh-agent to serve your private key and passphrase prior to running vagrant up. E.g.
```
$ eval `ssh-agent`
$ ssh-add ~/.ssh/google_compute_engine  # i.e. ssh-add your_private_key.  Enter your passphrase when prompted and hit return
$ ssh-add -l # to verify your key has been added
```
- The GCS deployment might be preferable for those users with slow internet access as it avoids the need to download the Ubuntu binary to the local laptop. 
- the helm install can take a while and lacks a progress indicator (sadly).  The timeout can be extended by modifying TIMEOUT_SECS="2400s" in scripts/mini-loop-install-local. 
- Once the fixes for mojaloop to enable helm3 and kubernetes version 1.17 and 1.18  have been put back into the mojaloop repo and helm repository, the access to vessels-tech repo will no longer be needed and further simplification of the install can be done.
- useful vagrant commands 
```
vagrant status # shows running vms
vagrant halt # stops vm but does not destroy
vagrant up # starts vm , use --provision flag to re-run provisioning
vagrant destory # destroys VM (will terminate resources / save money if using GCS)
```


mini-loop is tested so far with:
- OSX VirtualBox host
- google cloud service
- Virtualbox 6.1.6
- ubuntu 1804 guest (via hashicorp published vagrant box)
- vagrant  2.2.7
