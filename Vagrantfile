# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# define hostname
NAME = "mojaloopvm"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "hashicorp/bionic64"
  config.vm.box_version = "1.0.282"
  config.vm.define NAME
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 8181, host: 2223

  config.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
    vb.gui = false
    vb.memory = 8192
    vb.cpus = 2
    vb.name = NAME
  end

  config.vm.provision "shell", inline: <<-SHELL
  
    export RELEASE=1.18
    export PATH=$PATH:/snap/bin
    echo $PATH

    echo "installing packages"
    apt install git -y
    apt install nodejs -y 
    apt install npm -y
    npm install npm@latest -g
    npm install -g newman
    
    echo "clone postman tests for Mojaloop"
    chown vagrant /home/vagrant/.config 
    chgrp vagrant /home/vagrant/.config
    git clone https://github.com/mojaloop/postman.git

    echo "MojaLoop: run update ..."
    apt update

    echo "MojaLoop: installing snapd ..."
    apt install snapd -y

    echo "MojaLoop: installing microk8s release $RELEASE ... "
    sudo snap install microk8s --classic --channel=$RELEASE/stable

    echo "MojaLoop: enable helm ... "
    microk8s.enable helm3 
    echo "MojaLoop: enable dns ... "
    microk8s.enable dns
    echo "MojaLoop: enable storage ... "
    microk8s.enable storage
    echo "MojaLoop: enable ingress ... "
    microk8s.enable ingress
    echo "MojaLoop: enable istio ... "
    microk8s.enable istio
    echo "MojaLoop: initialise helm ... "
    microk8s.helm3 init

#
    echo "MojaLoop: add repos and deploy helm charts ..." 
    microk8s.helm3 repo add mojaloop http://mojaloop.io/helm/repo/
    microk8s.helm3 repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
    microk8s.helm3 repo add kiwigrid https://kiwigrid.github.io
    microk8s.helm3 repo add elastic https://helm.elastic.co
    microk8s.helm3 repo update
    microk8s.helm3 list
      
    # echo "MojaLoop: install nginx-ingress ..."   
    # microk8s.helm3 --namespace kube-public install stable/nginx-ingress
    
    echo "MojaLoop: install postman ..."   
    sudo snap install postman

    echo "MojaLoop: add convenient aliases..." 
    snap alias microk8s.kubectl kubectl
    snap alias microk8s.helm3 helm

    #echo "MojaLoop: Deploy mojaloop" 
    # Note troubleshooting guide and the need for updated values.yml
    # see https://mojaloop.io/documentation/deployment-guide/deployment-troubleshooting.html#31-ingress-rules-are-not-resolving-for-nginx-ingress-v022-or-later
    # TODO : verify that these values.yml updates are needed for the ingress re-write rules and then
    #        incorporate this fix here. use helm show values to capture the latest values.yml file
    #helm --namespace demo --name moja install mojaloop/mojaloop
    
    echo "MojaLoop: add vagrant user to microk8s group"
    usermod -a -G microk8s vagrant

    # TODO : 
    # add tests and run tests now
    # or perhaps run the test from the CI pipeline
SHELL

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end
