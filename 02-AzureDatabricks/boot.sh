#!/bin/bash

# get our stuff
. ./utils.sh
. ./environment.sh
. ./api-versions.sh

# start clean
clear

# variables comes here
UNIQUE_EH_NAME=eh$UNIQUE_NAME_FIX
UNIQUE_EH_NAMESPACE=ehns$UNIQUE_NAME_FIX
UNIQUE_STORAGE_NAME=blob$UNIQUE_NAME_FIX
UNIQUE_WORKSPACE_NAME=dbws$UNIQUE_NAME_FIX
BOOTSTRAP_STORAGE_ACCOUNT=bootstrap$UNIQUE_NAME_FIX


#Start by logging in to your Azure account and selecting the right subscription
display_progress "Logging in to subscription {$SUBSCRIPTION}"
az login -o table
az account set --subscription ${SUBSCRIPTION}

# create the resource group
display_progress "Creating resource group ${RESOURCE_GROUP}"
az group create -n ${RESOURCE_GROUP} -l ${LOCATION}

# create storage account
display_progress "Creating bootstrap account ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
az storage account create -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -l ${LOCATION} --sku Standard_LRS

# get connection string storage account
display_progress "Retrieving connection string for ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} -o tsv)

# create the storage container
display_progress "Creating bootstrap container in storage account"
az storage container create -n bootstrap

# create the SAS token to access it and upload files
display_progress "Generating SAS tokens"
STORAGE_SAS_TOKEN="?$(az storage container generate-sas -n bootstrap --permissions lr --expiry $(date ${plus_one_year} -u +%Y-%m-%dT%H:%mZ) -o tsv)"

# get right url
display_progress "Retrieving final destination uri for uploading files"
BLOB_BASE_URL=$(az storage account show -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -o json --query="primaryEndpoints.blob" -o tsv)

# get ready to upload file
display_progress "Uploading files to bootstrap account"
for file in *; do
    echo "uploading $file"
    az storage blob upload -c bootstrap -f ${file} -n ${file} &>/dev/null
done

# Mark & as escaped characters in SAS Token
ESCAPED_SAS_TOKEN=$(echo ${STORAGE_SAS_TOKEN} | sed -e "s|\&|\\\&|g")
azuredeploy_URI="${BLOB_BASE_URL}bootstrap/azuredeploy.json${STORAGE_SAS_TOKEN}"

# replace with right versions
replace_versions azuredeploy.parameters.template.json azuredeploy.parameters.json

# replace additional parameters in parameter file
sed --in-place=.bak \
-e "s|<uniqueNameFix>|${UNIQUE_NAME_FIX}|" \
-e "s|<projectName>|${PROJECT_NAME}|" \
-e "s|<bootstrapStorageAccount>|${BOOTSTRAP_STORAGE_ACCOUNT}|" \
-e "s|<bootstrapStorageAccountSas>|${ESCAPED_SAS_TOKEN}|" \
-e "s|<bootstrapStorageAccountUrl>|${BLOB_BASE_URL}|" \
-e "s|<eventHubNameSpace>|${UNIQUE_EH_NAMESPACE}|" \
-e "s|<eventHubName>|${UNIQUE_EH_NAME}|" \
-e "s|<storageAccountName>|${UNIQUE_STORAGE_NAME}|" \
-e "s|<workspaceName>|${UNIQUE_WORKSPACE_NAME}|" \
azuredeploy.parameters.json

display_progress "Deploying azuredeploy template into resource group"
az group deployment create -g ${RESOURCE_GROUP} --template-uri ${azuredeploy_URI} --parameters @azuredeploy.parameters.json --output json > azuredeploy.output.json

# azuredeploy deployment completed
display_progress "azuredeploy deployment completed"
azuredeploy_OUTPUT=$(cat azuredeploy.output.json)

# clean up
display_progress "Cleaning up"
az storage account delete --resource-group ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} --yes

# Get namespace connection string
display_progress "Get connection string"
az eventhubs namespace authorization-rule keys list --resource-group ${RESOURCE_GROUP} --namespace-name ${UNIQUE_EH_NAMESPACE} --name RootManageSharedAccessKey

# all done
display_progress "Deployment completed"



