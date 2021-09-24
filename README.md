# Mini-loop with K8s v1.20
Opinionated Mojaloop 'in a box' using Vagrant, K8s and Helm

Quick start
```bash
git clone https://github.com/tdaly61/mini-loop.git
cd mini-loop/vbox-deploy
vagrant up
```

## Overview

Mini-loop is a simple, opinonated 'out of the box' installation of [Mojaloop](https://mojaloop.io) for test and demonstration purposes. The goal is to make it easy and reliable to deploy Mojaloop locally.
This project automates the instructions for the linux installation in the mojaloop documentation at https://docs.mojaloop.io/documentation/deployment-guide/local-setup-linux.html. 
## Description / Approach

Using Hashicorp Vagrant, a VirtualBox Ubuntu VM is created and all of the components required to run mojaloop are automatically installed and configured into this VM. Once the VM is booted the mojaloop helm chart is deployed and the mojaloop kubernetes pods and services created, the mini-loop configuration automatically runs the mojaloop testing toolkit (https://docs.mojaloop.io/documentation/mojaloop-technical-overview/ml-testing-toolkit/) using "helm testr ml". The testing toolkit then performs the data setup and executes the Golden_Path test collections against this mojaloop installation using localhost.  

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
- vagrant-google plugin
- vagrant-env plugin
```bash
vagrant plugin install vagrant-google vagrant-env
```

- Google Cloud SDK (https://cloud.google.com/sdk/docs/downloads-versioned-archives and https://cloud.google.com/sdk/install )
- Google Cloud Service accounts and service account key ( https://cloud.google.com/iam/docs/creating-managing-service-account-keys ) 
- Google Cloud ssh keys established. See the [vagrant-google guide](https://github.com/mitchellh/vagrant-google#ssh-support) and [this-video](https://www.youtube.com/watch?v=JGcW1QdEQGs) for more information on how to do this.

## Setup

### Local (Virtualbox)
```bash
git clone https://github.com/tdaly61/mini-loop.git
cd mini-loop/vbox-deploy
vagrant up #creates the virtualbox VM, boots and configures the OS
```
## Using the testing Toolkit WebUI and Mobile Simulators 
ensure your current directory is the directory from which you ran "vagrant up" 
```bash
vagant ssh # to login as user you specified in the override.ssh.username = above

# on gcp, your user may not be vagrant
# mojaloop is deployed and owned by the vagrant user
# password is `vagrant`
su - vagrant 
cd /vagrant
./scripts/_example_transfer.sh
```

## Architecture

Mini-Loop deploys a single instance kubernetes cluster inside a Vagrant box running either locally or in GCP. Here's a rough idea of what that looks like:

![](./mini_loop_arch.svg)

Additionally, Vagrant copies (or mounts in the case of local) across the scripts you need to bootstrap the environment.

Feel free to ssh into your running Vagrant box, and try out the following commands:
```bash
# ssh into the running box
vagrant ssh

# switch to sudo user - this is just a hacky workaround since kubectl is owned by a different user
sudo su

# view the running pods
kubectl get po

# tail some logs
kubectl logs -f <pod_name>

# view the deployments
kubectl get deployments

# list the helm deployments
helm list
```

## Handy Vagrant Commands:

```bash
vagrant status # shows running vms

vagrant halt # stops vm but does not destroy

vagrant up # starts vm , use --provision flag to re-run provisioning

vagrant destroy # destroys VM (will terminate resources / save money if using GCS)
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
- the helm install can take a while and lacks a progress indicator (sadly).  The timeout can be extended by modifying TIMEOUT_SECS="2400s" in scripts/01_install_miniloop.sh . 
- Once the fixes for mojaloop to enable helm3 and kubernetes version 1.17 and 1.18  have been put back into the mojaloop repo and helm repository, the access to vessels-tech repo will no longer be needed and further simplification of the install can be done.



mini-loop is tested so far with:
- OSX VirtualBox host
- google cloud service
- Virtualbox 6.1.6
- ubuntu 1804 guest (via hashicorp published vagrant box)
- vagrant  2.2.7

## FAQ

1. I think it installed correctly, but how do I verify that everything is working?

Be default we execute a subset of the Mojaloop Golden Path tests, so if your logs on `vagrant up` look ok, then you can be confident that everything is up and running just fine.

You can also run a test transfer yourself, see [make a test transfer](#make-a-test-transfer)


2. I'm having issues with `\r`'s on Windows (`$'\r': command not found`)

When testing on Windows, we observed that carriage returns (`\r` characters) were being appended to our scripts, which causes some bash scripts to fail once Vagrant mounts the scripts into the vagrant box. Our workaround for the following is to remove them inline and pipe to bash, like so:

```bash
sed 's/\r$//' /vagrant/scripts/_example_transfer.sh | /bin/bash
```

You could also update the file in place like so:
```bash
sed -i 's/\r$//' /vagrant/scripts/_example_transfer.sh
/vagrant/scripts/_example_transfer.sh
```

This however could create issues down the line where you may need to re-run the above script if you make changes to the `_example_tranfer.sh` script from the Windows host.