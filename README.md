# mini-loop v2.0 with K8s v1.20
Simple, scripted/automated installation of Mojaloop (http://mojaloop.io) 

Just do this ...
Assuming you have an x86_64 environment running Ubuntu release 16, 18 or 20 and are logged in as a non-root user (e.g. mluser)
```bash
cd $HOME
git clone https://github.com/tdaly61/mini-loop.git                   # clone the mini-loop scripts into the mluser home directory
sudo su -                                                            # su to root alternatively login in as root 
~mluser/install/mini-loop/ubuntu/k8s-install.sh -m install -u mluser # this will install and configure microk8s kubernetes and prepare for mojaloop deployment
~mluser/install/mini-loop/scripts/01_install_miniloop.sh             # this will delploy and configure the mojaloop helm chart 
```

## Description 

mini-loop is a simple, automated installation of [Mojaloop](https://mojaloop.io) for test , development and demonstration purposes. The goal is to make it easy, quick and scriptable to deploy Mojaloop in 
a variety of local or cloud environments. 

Example environments include:-
- an x86_64 laptop or server running ubuntu on bare metal 
- an x86_64 laptop or server running ubuntu as a guest VM (say using virtualbox , prarallels, qemu or similar) 
- an appropriately sized x86_64 ubuntu cloud instance running in any of the major cloud vendors

Mini-loop also allows for easy configuration of the helm charts, an example values file is provided in the mini-loop/install/mini-loop/etc directory and further mojaloop configuration 
instructions are available at https://github.com/mojaloop/helm. 
 
Essentially this project automates the instructions for the linux installation in the mojaloop documentation at https://docs.mojaloop.io/documentation/deployment-guide/local-setup-linux.html. 

## Prerequisites 
- running x86_64 ubuntu environment (ubuntu release 16,18 or 20)
- non-root user (with bash shell)
- git installed   
- min 6GB ram available  (8GB or more recommended) 
- min 64GB storage available
- broadband internet connection (for downloading helm charts and container images )


## Notes:
- the mini-loop scripts output messages to help guide your deployment , please pay attention to these messages
- other versions of ubuntu and other linux OS's will likely work but are not really tested at this time
- each of the scripts has a -h flag to show params and give examples of how to use and customise
- Helm chart modification is enabled by providing your own values file, simply change the help deploy command in the  01_install_miniloop.sh to point to your customised values i.e. alter 
  the -f value in the line `helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE"  mojaloop/mojaloop --version $MOJALOOP_VERSION -f $ETC_DIR/miniloop_values.yaml `
- mini-loop 2.0 deploys a single node kubernetes environment , this might change in the future
- reading the scripts can be a useful way to learn about both kubernetes (microk8s) and mojaloop deployment. As well as the automation the scripts are intended to provide a starting point, for further customisation. 
  For instance it should be easy for the user to add extra nodes to the microk8s cluster or as mentioned above to modify the mojaloop configuration etc. 

## notable changes in mini-loop v2.0
- re-worked all the scripts to function in any running ubuntu enviroment as described above
- updated to Mojaloop v13.1.1
- updated K8s version to v1.20.x
- removed all automation that created the ubuntu enviromnent, this is now left to the user. It became obvious that the utility of mini-loop install would be far 
  improved by making this change
- removed the script to run the testing toolkit, instead `helm test` is utilised and the user guided as how to run helm test from the mini-loop scripts

## FAQ

1. I think it installed correctly, but how do I verify that everything is working?
   The mini-loop scripts test several of the mojaloop API /health endpoints and will report an errors other also `helm test` is your friend!  
   See the instructions at the end of the mojaloop deployment for instructions on running the tests and also refer to the testing section of 
   https://github.com/mojaloop/helm 


2. I'm having issues with `\r`'s on Windows (`$'\r': command not found`)
   Currently deployment into windows environments is not supported , please let me know (tdaly61@gmail.com) or on the mojaloop slack if this is a significant problem