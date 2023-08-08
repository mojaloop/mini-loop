# A Deployable Package for Mifos/Fineract, Payment Hub EE, and Mojaloop (Mojafos)

## Introduction

The deployable package is intended to simplify and automate the deployment process of three software applications, namely Mojaloop, PaymentHub, and Fineract, onto a Kubernetes cluster. This package aims to streamline the deployment process, reduce manual errors, and enable someone to demo how these softwares can work together. 

## Purpose

The purpose of this document is to provide a comprehensive overview of the deployable package, detailing its functionalities, architecture, and usage.

## Scope

The Deployable Package will perform the following tasks:

- Accept user input to specify the Kubernetes cluster's configuration or create a new kubernetes cluster. 
- Retrieve the necessary deployment helm charts for the software applications.
- Edit each software application helm chart in order for the software to function correctly in the kubernetes cluster.
- Create Kubernetes resources for each software application in their respective namespace.
- Configure environment variables and secrets as needed for the software applications.
- Provide status updates on the deployment process.
- Deploy infrastructure in a single namespace
- Check the health of each deployed application to see if it is ready to serve requests.
