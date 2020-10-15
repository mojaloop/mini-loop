# Mini-loop
Opinionated Mojaloop 'in a box' using Vagrant, K8s and Helm

Quick start
```bash
git clone https://github.com/tdaly61/mini-loop.git
cd mini-loop/vbox-deploy
vagrant up
```

## Overview

Mini-loop is a simple, opinonated 'out of the box' installation of [Mojaloop](https://mojaloop.io) for test and demonstration purposes. The goal is to make it easy and reliable to deploy Mojaloop both locally or in a cloud environment.
This project essentially automates the instructions for the linux installation in the mojaloop documentation at https://mojaloop.io/documentation/deployment-guide/local-setup-linux.html#mojaloop-setup-for-linux-ubuntu.
There are however some minor variations from these onboarding docs, such as using helm3 charts and enabling kubernetes version 1.18.  See [#1070-helm3](https://github.com/mojaloop/project/issues/1070) and [#219-kubernetes-version](https://github.com/mojaloop/helm/issues/219) for more deatils.

## Description / Approach

Using Hashicorp Vagrant, a VirtualBox Ubnutu VM or Google Cloud VM is created and all of the components required to run mojaloop are automatically installed and configured into this VM. Once the VM is booted the mojaloop helm chart is deployed and the mojaloop kubernetes pods and services created, the mini-loop configuration automatically runs the /vagrant/scripts/02_seed_mojaloop.sh script to load test data into the mojaloop application and then executes the mojaloop postman/newman based Golden_Path test collections against this mojaloop installation using localhost.  

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

### Google Cloud Services
1. Assuming vagrant is installed and running and the google cloud prerequisites as detailed above established.

```bash
git clone https://github.com/tdaly61/mini-loop.git
cd mini-loop/gcs-deploy
```

2. Copy the `.env.example` file to `.env`, and edit it for the following parameters:

```bash
cp .env.example .env
```

3. Edit the `.env` file and enter correct values for
  - `GCP_PROJECT_ID` - the id of your project in Google Cloud
  - `GCP_JSON_KEY_PATH` - The full path to your service account key `.json` file
  - `CGP_SSH_USERNAME` - a username you 
  - `CGP_SSH_KEY` - the path to the ssh private key you set up to use with GCP

Here's an example of a completed `.env` file:

```
GCP_PROJECT_ID=my-new-project
GCP_JSON_KEY_PATH=~/default.json
CGP_SSH_USERNAME=alice
CGP_SSH_KEY=~/.ssh/id_rsa
```

> Note: Having SSH troubles?
> Check out the [vagrant-google](https://github.com/mitchellh/vagrant-google#ssh-support) section on SSH support


4. Run `vagrant up --provider=google`!

```bash
# uses the vagrant google-plugin and creates the google cloud VM, boots and configures the OS
vagrant up --provider=google 
```

## Make a Test Transfer
ensure your current directory is the directory from which you ran "vagrant up" 
```bash
vagant ssh # to login as user you specified in the override.ssh.username = above
sudo su - 

su - vagrant #mojaloop is deployed and owned by the vagrant user
cd /vagrant
[ todo: add instructions for windows ]
./scripts/_example_transfer.sh
```

## Handy Vagrant Commands:

```bash
vagrant status # shows running vms

vagrant halt # stops vm but does not destroy

vagrant up # starts vm , use --provision flag to re-run provisioning

vagrant destory # destroys VM (will terminate resources / save money if using GCS)
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