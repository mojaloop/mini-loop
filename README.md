# mini-loop v3.0 with Microk8s v1.20 or k3s v1.21
Simple, scripted/automated installation of Mojaloop (http://mojaloop.io) for demo, test, training and development. 

## Deployment Instructions option #1 install and use Microk8s 
Assuming you have an x86_64 environment running Ubuntu release 16, 18 or 20 and are logged in as a non-root user (e.g. mluser)
```bash
login as mluser                                                      # i.e. login as an existing non-root user we use mluser just as an example
cd $HOME                                                      
git clone https://github.com/tdaly61/mini-loop.git                   # clone the mini-loop scripts into the mluser home directory
sudo su -                                                            # su to root alternatively login in as root 
~mluser/mini-loop/install/mini-loop/ubuntu/k8s-install.sh -m install -u mluser -k microk8s # install and configure microk8s & prepare for mojaloop deploy
login as mluser or su - mluser                                      # you need a fresh login as mluser to ensure .bashrc is sourced.
~mluser/mini-loop/install/mini-loop/scripts/01_install_miniloop.sh  # deploy and configure the mojaloop helm chart 
```

## Deployment Instructions option #2 install and use Rancher k3s
Assuming you have an x86_64 environment running Ubuntu release 16, 18 or 20 and are logged in as a non-root user (e.g. mluser)
```bash
login as mluser                                                      # i.e. login as an existing non-root user we use mluser just as an example
cd $HOME                                                      
git clone https://github.com/tdaly61/mini-loop.git                   # clone the mini-loop scripts into the mluser home directory
sudo su -                                                            # su to root alternatively login in as root 
~mluser/mini-loop/install/mini-loop/ubuntu/k8s-install.sh -m install -u mluser -k k3s # install and configure k3s & prepare for mojaloop deploy
login as mluser or su - mluser                                      # you need a fresh login as mluser to ensure .bashrc is sourced.
~mluser/mini-loop/install/mini-loop/scripts/01_install_miniloop.sh  # deploy and configure the mojaloop helm chart 
```

## Running the Testing Toolkit via ```helm test```
as the non-root user (e.g. mluser)
```
helm test ml --logs 
```
For more detailed instructions on running the helm tests see "Testing Deployments" section of : https://github.com/mojaloop/helm

## accessing Mojaloop from beyond "localhost" (from a linux or OSX laptop)
The mini-loop scripts add the required host names to the 127.0.0.1 entry in the /etc/hosts of the install system"  To access mojaloop from beyond this system where mojaloop is installed it is necessary to:- 
1. ensure that http / port 80 is accessible on the target system.  For instance if mini-loop has installed Mojaloop onto a VM in the cloud then it will be necessary to ensure that the cloud network security rules allow inbound traffic on port 80 to that VM.
2. copy the hosts on 127.0.0.1 from the /etc/hosts of the system where you installed Mojaloop and add these hosts to an entry for the external/public ip address of that install system in the /etc/hosts file of the laptop you are using. 

 For example if Mojaloop is installed on a cloud VM with a public IP of 192.168.56.100  The add an entry to your laptop's /etc/hosts similar to ...
```
192.168.56.100 ml-api-adapter.local central-ledger.local account-lookup-service.local account-lookup-service-admin.local quoting-service.local central-settlement-service.local transaction-request-service.local central-settlement.local bulk-api-adapter.local moja-simulator.local sim-payerfsp.local sim-payeefsp.local sim-testfsp1.local sim-testfsp2.local sim-testfsp3.local sim-testfsp4.local mojaloop-simulators.local finance-portal.local operator-settlement.local settlement-management.local testing-toolkit.local testing-toolkit-specapi.local
```
You should now be able to browse or curl to Mojaloop url's e.g. http://central-ledger.local/health

## Description 

mini-loop is a simple, automated installer for and installation of [Mojaloop](https://mojaloop.io) for test , development and demonstration purposes. The goal is to make it easy, quick and scriptable to deploy Mojaloop for test, demonstration, education etc in a variety of local or cloud environments. 

Example environments include:-
- an x86_64 laptop or server running ubuntu on bare metal 
- an x86_64 laptop or server running ubuntu as a guest VM (say using virtualbox , prarallels, qemu or similar) 
- an appropriately sized x86_64 ubuntu cloud instance running in any of the major cloud vendors

mini-loop also allows for easy configuration of the helm charts, an example values file is provided in the mini-loop/install/mini-loop/etc directory and further mojaloop configuration 
instructions are available at https://github.com/mojaloop/helm. 
 
Essentially this project automates the instructions for the linux installation in the mojaloop documentation at https://docs.mojaloop.io/documentation/deployment-guide/local-setup-linux.html. 

## Prerequisites 
- running x86_64 ubuntu environment (ubuntu release 16,18 or 20)
- non-root user (with bash shell)
- git installed   
- min 6GB ram available  (8GB or more recommended) 
- min 64GB storage available
- broadband internet connection from the ubuntu OS (for downloading helm charts and container images )

## Notes:
- Mojaloop code is developed to be deployable in a robust, highly available and highly secure fashion *BUT* the mini-loop deployment focusses on simplicity and hence is not deploying Mojaloop in either a robust fashion nor a secure fashion.  So the mini-loop deployment of Mojaloop is *NOT* suitable for production purposes rather it is for trial, test , education and demonstration purposes only!
- the mini-loop scripts output messages to help guide your deployment , please pay attention to these messages
- each of the scripts has a -h flag to show parameters and give examples of how to use and customise
- helm chart modification is enabled by providing your own values file, simply change the `helm deploy` command in the  01_install_miniloop.sh to point to your
  customised values i.e. alter the -f value in the line 
  `helm install $RELEASE_NAME --wait --timeout $TIMEOUT_SECS  --namespace "$NAMESPACE"  mojaloop/mojaloop --version $MOJALOOP_VERSION -f $ETC_DIR/miniloop_values.yaml `
- mini-loop currently deploys a single node kubernetes environment. 
- reading the scripts can be a useful way to learn about both kubernetes (microk8s / k3s ) and mojaloop deployment.
- The the scripts are intended to provide a starting point, for further customisation. For instance it should be easy for the user to 
  add extra nodes to the kubernetes cluster or as mentioned above to modify the mojaloop configuration etc. 
- please note that the installation adds the /etc/hosts entries for the endpoints configured in the $ETC_DIR/miniloop_values.yaml file if you 
  use different values you will likely have to adjust the /etc/hosts endpoints

## known issues
1. Again mini-loop deployment of Mojaloop has only been tested properly with ubuntu as specified above.
2. Not contradicting the point above BUT the k3s option should(?) work on other linux distros other than Ubuntu. It has been tested on fedora36 where there were some issues around docker volumes that are not yet fully debugged.  It is unclear if these docker issues will occur on other redhat type linux distros as they do not occur on Ubuntu where k3s with docker seems to work just fine.
3. Other than Ubuntu it has only tested on fedora36 where due to some issues around the inclusion of an old percona helm chart in the mojaloop helm chart the k3s installation is using docker and not containerd and on fedora36 this caused some issues around volumes that are not yet fully debugged.  It is unclear if these docker issues will occur on other redhat type linux distros and they do not occur on Ubuntu where k3s with docker sems to work just fine.
4. The versions of kubernetes are deliberately hardcoded in mini-loop and that is a limitation that is intended to be lifted in the near future. This is done os that the mojaloop helm charts and nginx and networking values are reliably set and the container runtime issues re avoided.  Currently mini-loop ignores the commandline version flag and uses only  :-
    * MicroK8s : v1.20
    * k3s      : v1.21

## Notable changes in mini-loop v3.0
- inclusion of rancher k3s as an option. This is mainly to assist mini-loop being available over more linux distributions as Microk8s is only installable with snapd and snapd seems very complex (to install) and unreliable on current linux distributions other than Ubuntu (where it seems to work nicely) 
- hardcoded the kubernetes releases that can be used (see above)


## Notable changes in mini-loop v2.0
- re-worked all the scripts to function in any running ubuntu enviroment as described above
- updated to default to Mojaloop v13.1.1
- updated K8s version to v1.20.x
- removed all automation that created the ubuntu enviromnent, this is now left to the user. It became obvious that the utility of mini-loop install would be far 
  improved by making this change
- removed the script to run the testing toolkit, currently `helm test` is utilised and the user guided as how to run helm test from the mini-loop scripts


## FAQ
1. I think it installed correctly, but how do I verify that everything is working?
   The mini-loop scripts test several of the mojaloop API /health endpoints and will report an errors.  Also `helm test` is your friend!  
   See the instructions at the end of the mojaloop deployment for instructions on running the tests and also refer to the testing section of 
   https://github.com/mojaloop/helm 

2. I'm having issues with `\r`'s on Windows (`$'\r': command not found`)
   Currently deployment into windows environments is not supported , please let me know (tdaly61@gmail.com) or on the mojaloop slack if this is a significant problem