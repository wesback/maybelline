#!/bin/bash

# get our stuff
 . ./utils.sh
 . ./environment.sh

# start clean
clear

# main deployment
# create the main deployment either in background or not
display_progress "Deploying main template into resource group using Terraform"
# enter 
pushd ./tf
# replace additional parameters in parameter file
sed -i.bak \
-e "s|<unique-name-fix>|${UNIQUE_NAME_FIX}|" \
-e "s|<project-name>|${PROJECT_NAME}|" \
-e "s|<resource-group>|${RESOURCE_GROUP}|" \
-e "s|<location>|${LOCATION}|" \
-e "s|<subscription-id>|${SUBSCRIPTION_ID}|" \
-e "s|<tenant-id>|${TENANT_ID}|" \
-e "s|<client-id>|${SERVICE_PRINCIPAL_ID}|" \
-e "s|<client-secret>|${SERVICE_PRINCIPAL_KEY}|" \
-e "s|<cluster-ssh-key-value>|${CLUSTER_SSH_KEY_VALUE}|" \
-e "s|<cluster-service-principal-id>|${CLUSTER_SERVICE_PRINCIPAL_ID}|" \
-e "s|<cluster-service-principal-key>|${CLUSTER_SERVICE_PRINCIPAL_KEY}|" \
-e "s|<cluster-service-principal-oid>|${CLUSTER_SERVICE_PRINCIPAL_OID}|" \
input.parameters.tfvars 
# initialize terraform
terraform init
# apply configuration
terraform apply -var-file=input.parameters.tfvars -auto-approve &> ${LOG_DIR}/main.tf.apply.log
# all done
display_progress "Main deployment completed"
MAIN_OUTPUT=$(terraform output -json)
# read and parse outputs
REGISTRY_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.registry_name.value')
REGISTRY_USER_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.registry_user_name.value')
REGISTRY_PASSWORD=$(echo "${MAIN_OUTPUT}" | jq -r '.registry_password.value')
VNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.vnet_id.value')
CLUSTER_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.cluster_name.value')
ls
CLUSTER_VNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.cluster_vnet_id.value')
CLUSTER_SUBNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.cluster_subnet_id.value')
# leave
popd


# assign security 
display_progress "Setting up role assignments"
docker login -u "${REGISTRY_USER_NAME}" -p "${REGISTRY_PASSWORD}" "${REGISTRY_NAME}.azurecr.io"
REGISTRY_ID=$(az acr show --resource-group ${RESOURCE_GROUP} --name ${REGISTRY_NAME} --query "id" --output tsv)

# provide access to registry for cluster
az role assignment create --assignee-object-id ${CLUSTER_SERVICE_PRINCIPAL_OID} --scope ${REGISTRY_ID} --role AcrPull
# provide access to netzwork for cluster
az role assignment create --assignee-object-id ${CLUSTER_SERVICE_PRINCIPAL_OID} --scope ${VNET_ID} --role Contributor

display_progress "Connecting to cluster"
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}
# get nodes
display_progress "get cluster nodes"
kubectl get nodes

# deploy helm service account
display_progress "installing and configuring helm"
kubectl apply -f ./helm-rbac.yaml
# configure helm
helm init --service-account tiller --node-selectors "beta.kubernetes.io/os"="linux"
# upgrade
helm init --upgrade --service-account tiller

# display_progress "installing and configuring prometheus"
# # add repo
# helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/
# # install prometheos operator with rbac enabled
# helm install coreos/prometheus-operator --name prometheus-operator --namespace monitoring
# helm install coreos/kube-prometheus --name kube-prometheus --namespace monitoring

# display_progress "check prometheus"
# # check prometheus
# kubectl get prometheus --all-namespaces -l release=kube-prometheus
# kubectl get servicemonitor --all-namespaces -l release=kube-prometheus
# kubectl get service --all-namespaces -l release=kube-prometheus -o=custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name

# # install dev spaces
# display_progress "installing and configuring azure dev spaces"
# az aks use-dev-spaces -g ${RESOURCE_GROUP} -n ${CLUSTER_NAME}

# clean up
display_progress "Cleaning up"
# az storage account delete --resource-group ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} --yes

# all done
display_progress "Deployment completed"