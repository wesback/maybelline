#!/bin/bash

if [[ "${1}" == "login" ]]; then
    az login
fi

if [[ "${1}" == "eradicate" ]]; then
    echo "erasing"
fi

if [[ "${1}" == "clean" ]]; then
    DATA=$(az ad sp list --show-mine)
    LENGTH=$(echo ${DATA} | jq -rM '. | length')
    echo "Found: ${LENGTH}"
    for row in $(echo "${DATA}" | jq -r '.[] | @base64'); do
        _jq() {
        echo ${row} | base64 -d | jq -r ${1}
        }
        OBJECT_ID=$(_jq '.objectId')
        DISPLAY_NAME=$(_jq '.displayName')
        if [[ ${DISPLAY_NAME} == *cli* ]] ; then
            echo "Deleting ${DISPLAY_NAME}"
            az ad sp delete --id ${OBJECT_ID}
        fi
    done
fi

if [[ "${1}" == "init" ]]; then
    # prepare including max support
    plus_one_year="-d +1year"
    [[ $(uname) == "Darwin" ]] && plus_one_year="-v+1y"

    # create our principal and save the credentials
    az ad sp create-for-rbac > ./deployment-credentials.json
    # get info 
    SUBSCRIPTION_ID=$(az account show | jq -r '.id')
    SERVICE_PRINCIPAL_ID=$(cat ./deployment-credentials.json | jq -r '.appId')
    # set owner role
    az role assignment create \
            --role Owner \
            --scope /subscriptions/${SUBSCRIPTION_ID} \
            --assignee ${SERVICE_PRINCIPAL_ID}

    # create cluster credentials
    az ad sp create-for-rbac --skip-assignment > ./cluster-credentials.json
fi

if [[ "${1}" == "deploy" ]]; then
    ./deploy.sh -l westeurope -s 886b84e6-68e5-4a4d-8230-61235c4a2087  -sshf ./id_rsa.pub -dcf ./deployment-credentials.json -ccf ./cluster-credentials.json -g ${2}
fi

if [[ "${1}" == "install-prometheus" ]]; then
    # create our namespace
    kubectl create namespace monitoring
    # create cluster role
    kubectl create -f prometheus-cluster-role.yaml
    # create config map
    kubectl create -f prometheus-config-map.yaml -n monitoring
    # let's deploy
    kubectl create -f prometheus-deployment.yaml -n monitoring        
    # let's add service
    kubectl create -f prometheus-service.yaml -n monitoring        
    # let's add service
    kubectl create -f kubernetes-dashboard-service.yaml -n kube-system        
    # # prepare git container
    # mkdir -vp ${HOME}/git
    # # get charts 
    # cd ${HOME}/git
    # git clone https://github.com/helm/charts.git
    # # install prometheus
    # cd ${HOME}/git
    # cd charts/stable/prometheus
    # helm install --name=prometheus . --namespace monitoring --set rbac.create=true
    # # install grafana
    # cd ${HOME}/git
    # cd charts/stable/grafana
    # helm install stable/grafana --set persistence.enabled=true --set persistence.accessModes={ReadWriteOnce} --set persistence.size=8Gi -n grafana --namespace monitoring
fi

if [[ "${1}" == "remove-prometheus" ]]; then
    # let's add service
    kubectl delete -f kubernetes-dashboard-service.yaml -n kube-system        
    # let's add service
    kubectl delete -f prometheus-service.yaml -n monitoring        
    # let's deploy
    kubectl delete -f prometheus-deployment.yaml -n monitoring        
    # create config map
    kubectl delete -f prometheus-config-map.yaml -n monitoring
    # create cluster role
    kubectl delete -f prometheus-cluster-role.yaml
    # create our namespace
    kubectl delete namespace monitoring
    # # prepare git container
    # mkdir -vp ${HOME}/git
    # # get charts 
    # cd ${HOME}/git
    # git clone https://github.com/helm/charts.git
    # # install prometheus
    # cd ${HOME}/git
    # cd charts/stable/prometheus
    # helm install --name=prometheus . --namespace monitoring --set rbac.create=true
    # # install grafana
    # cd ${HOME}/git
    # cd charts/stable/grafana
    # helm install stable/grafana --set persistence.enabled=true --set persistence.accessModes={ReadWriteOnce} --set persistence.size=8Gi -n grafana --namespace monitoring
fi

if [[ "${1}" == "install-kubernetes-dashboard" ]]; then
    # let's add service
    kubectl create -f kubernetes-dashboard-service.yaml -n kube-system        
fi

if [[ "${1}" == "remove-kubernetes-dashboard" ]]; then
    # let's add service
    kubectl delete -f kubernetes-dashboard-service.yaml -n kube-system        
fi
