#!/bin/bash

# get our stuff
. ./utils.sh
. ./environment.sh

# start clean
clear

# variables comes here
UNIQUE_EH_NAME=eh$UNIQUE_NAME_FIX
UNIQUE_EH_NAMESPACE=ehns$UNIQUE_NAME_FIX
UNIQUE_STORAGE_NAME=blob$UNIQUE_NAME_FIX


#Start by logging in to your Azure account and selecting the right subscription
display_progress "Logging in to subscription {$SUBSCRIPTION}"
az login
az account set --subscription ${SUBSCRIPTION}

# create the resource group
display_progress "Creating resource group ${RESOURCE_GROUP}"
az group create -n ${RESOURCE_GROUP} -l ${LOCATION}

# Create an Event Hubs namespace
display_progress "Creating event hubs namespace ${UNIQUE_EH_NAMESPACE}"
az eventhubs namespace create --name ${UNIQUE_EH_NAMESPACE} --resource-group ${RESOURCE_GROUP} -l ${LOCATION}

# Create an event hub
display_progress "Creating event hub ${UNIQUE_EH_NAMESPACE}"
az eventhubs eventhub create --name ${UNIQUE_EH_NAME} --resource-group ${RESOURCE_GROUP} --namespace-name ${UNIQUE_EH_NAMESPACE}

# Create a general purpose standard storage account
display_progress "Creating storage account ${UNIQUE_STORAGE_NAME}"
az storage account create --name ${UNIQUE_STORAGE_NAME} --resource-group ${RESOURCE_GROUP} --location ${LOCATION} --sku Standard_RAGRS --encryption blob

# List the storage account access keys
display_progress "Listing storage keys"
az storage account keys list --resource-group ${RESOURCE_GROUP} --account-name ${UNIQUE_STORAGE_NAME}

# Get namespace connection string
display_progress "Get connection string"
az eventhubs namespace authorization-rule keys list --resource-group ${RESOURCE_GROUP} --namespace-name ${UNIQUE_EH_NAMESPACE} --name RootManageSharedAccessKey


