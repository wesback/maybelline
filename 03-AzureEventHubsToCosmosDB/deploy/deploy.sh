#!/bin/bash
. ./utils.sh

function display_help() {
	echo -e "\n${PROJECT_NAME} deployment utility v1.0\n"
	echo -e "usage: deploy.sh -/-- options:\n"
	echo -e "\t--help, -h"
	echo -e "\t  displays more detailed help\n"
	echo -e "\t--resource-group, -g <resource group>"
	echo -e "\t  the resource group to deploy to\n"
	echo -e "\t--location, -l <location> "
	echo -e "\t  the location to deploy to\n"
	echo -e "\t--subscription-id, -u <subscription id>"
	echo -e "\t  the subscription id to use for deploying\n"
	echo -e "\t--tenant-id, -u <tenant id>"
	echo -e "\t  the tenant id to use for deploying\n"
	echo -e "\t--service-principal-id, -u <service principal id>"
	echo -e "\t  the service principal id to use for deploying\n"
	echo -e "\t--service-principal-key, -p <service principal key>"
	echo -e "\t  the service principal key to use for deploying\n"
	echo -e "\t--deployment-credentials-file, -dcf <deployment credentials file>"
	echo -e "\t  the deployment credentials key"
    echo -e "\t--cluster-credentials-file, -ccf <cluster credentials file>"
	echo -e "\t  the cluster credentials key"

}

# set some defaults
PROJECT_NAME="styx"
ROOT_DIR="$(dirname "$PWD")"
OUTPUT_DIR=${ROOT_DIR}/output
UNIQUE_NAME_FIX="$(dd if=/dev/urandom bs=6 count=1 2>/dev/null | base64 | tr '[:upper:]+/=' '[:lower:]abc')"
DEPLOYMENT_CREDENTIALS_FILE="none"

# parse the argumens
while true; do
  case "$1" in
	-h | --help ) display_help; exit 1 ;;
    -l | --location ) LOCATION="$2"; shift ; shift ;;
    -g | --resource-group ) RESOURCE_GROUP="$2"; shift ; shift ;;
    -t | --tenant-id ) TENANT_ID="$2"; shift ; shift ;;
    -u | --service-principal-id ) SERVICE_PRINCIPAL_ID="$2"; shift ; shift ;;
    -p | --service-principal-key ) SERVICE_PRINCIPAL_KEY="$2"; shift ; shift ;;
	-sshf | --cluster-ssh-key-file ) CLUSTER_SSH_KEY_FILE="$2"; shift ; shift ;;
    -ccf | --cluster-credentials-file ) CLUSTER_CREDENTIALS_FILE="$2"; shift ; shift ;;
	-dcf | --deployment-credentials-file ) DEPLOYMENT_CREDENTIALS_FILE="$2"; shift ; shift ;;
    -s | --subscription-id ) SUBSCRIPTION_ID="$2"; shift ; shift ;;
  -- ) shift; break ;;
    * ) break ;;
  esac
done

# tools required to be able to work
require_tool jq || exit 1
require_tool dos2unix || exit 1
require_tool terraform || exit 1

# validation checking
if [ ${DEPLOYMENT_CREDENTIALS_FILE} != "none" ]
	then 
	TENANT_ID=$(cat ${DEPLOYMENT_CREDENTIALS_FILE} | jq -r '.tenant')
	SERVICE_PRINCIPAL_ID=$(cat ${DEPLOYMENT_CREDENTIALS_FILE} | jq -r '.appId')
	SERVICE_PRINCIPAL_KEY=$(cat ${DEPLOYMENT_CREDENTIALS_FILE} | jq -r '.password')
fi
# validation checking
if [ -z ${LOCATION+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --location, -l is missing.\n"
	echo -e "\tusage: --location, -l [westeurope, westus, northeurope, ...]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${RESOURCE_GROUP+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --resource-group, -g is missing.\n"
	echo -e "\tusage: --resource-group, -g [NAME]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SUBSCRIPTION_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --subscription-id, -s is missing.\n"
	echo -e "\tusage: --subscription-id, -s [SUBSCRIPTION ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${TENANT_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --tenant-id, -u is missing.\n"
	echo -e "\tusage: --tenant-id, -t [TENANT ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-id, -u is missing.\n"
	echo -e "\tusage: --service-principal-id, -u [SERVICE PRINCIPAL ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_KEY+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-key, -p is missing.\n"
	echo -e "\tusage: --service-principal-key, -p [SERVICE PRINCIPAL KEY]"
	echo -e "\n"
	exit 1; 
fi

if [ -z ${CLUSTER_SSH_KEY_FILE+x} ]
        then
        display_help
        display_error "One or more missing or incorrect arguments\n"
        display_error "\terror: --cluster-ssh-key-file, -sshf is missing.\n"
        echo -e "\tusage: --cluster-ssh-key-file, -sshf [CLUSTER SSH KEY FILE]"
        echo -e "\n"
        exit 1;
fi

if [ -z ${CLUSTER_CREDENTIALS_FILE+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --cluster-credentials-file, -ccf is missing.\n"
	echo -e "\tusage: --cluster-credentials-file, -ccf [CLUSTER CREDENTIALS FILE]"
	echo -e "\n"
	exit 1; 
fi

# entering deployment environment
display_progress "Preparing deployment environment"
# prepare target environment
rm -rf ${OUTPUT_DIR} >/dev/null
# prepare deploy structure
mkdir -p ${OUTPUT_DIR}/deploy >/dev/null
cp -r * ${OUTPUT_DIR}/deploy >/dev/null
# cp -r `ls -A | grep -v "output"` ${OUTPUT_DIR}

# # prepare scripts dir
# mkdir -p ${OUTPUT_DIR}/scripts >/dev/null
# pushd ../scripts >/dev/null
# tar cf - --exclude=node_modules . | (cd ${OUTPUT_DIR}/scripts && tar xvf - ) >/dev/null
# popd >/dev/null

# prepare log dir
LOG_DIR=${OUTPUT_DIR}/logs
mkdir -p ${LOG_DIR} >/dev/null

# set proper variables
CLUSTER_SERVICE_PRINCIPAL_ID=$(cat "${CLUSTER_CREDENTIALS_FILE}" | jq -r '.appId')
CLUSTER_SERVICE_PRINCIPAL_KEY=$(cat "${CLUSTER_CREDENTIALS_FILE}" | jq -r '.password')
CLUSTER_SERVICE_PRINCIPAL_OID=$(az ad sp show --id ${CLUSTER_SERVICE_PRINCIPAL_ID} | jq -r '.objectId')

# entering deployment environment
display_progress "Entering deployment environment"
# create a different config file for azure cli so no conflict with existing user profile
export AZURE_CONFIG_DIR=${OUTPUT_DIR}/deploy/.azure-dev
# do explicit login
az login --service-principal -t ${TENANT_ID} -u ${SERVICE_PRINCIPAL_ID} -p ${SERVICE_PRINCIPAL_KEY} 
# select specified subscription
az account set --subscription ${SUBSCRIPTION_ID}
# extract principal object id
SERVICE_PRINCIPAL_OID=$(az ad sp show --id ${SERVICE_PRINCIPAL_ID} | jq -r '.objectId')

# pass the environment
cat <<-EOF > ${OUTPUT_DIR}/deploy/environment.sh
LOG_DIR="${LOG_DIR}"
OUTPUT_DIR="${OUTPUT_DIR}"
UNIQUE_NAME_FIX="${UNIQUE_NAME_FIX}"
LOCATION="${LOCATION}"
PROJECT_NAME="${PROJECT_NAME}"
RESOURCE_GROUP="${RESOURCE_GROUP}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"
TENANT_ID="${TENANT_ID}"
CLUSTER_SSH_KEY_FILE="${CLUSTER_SSH_KEY_FILE}"
CLUSTER_SSH_KEY_VALUE="$(cat ${CLUSTER_SSH_KEY_FILE})"
SERVICE_PRINCIPAL_ID="${SERVICE_PRINCIPAL_ID}"
SERVICE_PRINCIPAL_KEY="${SERVICE_PRINCIPAL_KEY}"
SERVICE_PRINCIPAL_OID="${SERVICE_PRINCIPAL_OID}"
CLUSTER_SERVICE_PRINCIPAL_ID="${CLUSTER_SERVICE_PRINCIPAL_ID}"
CLUSTER_SERVICE_PRINCIPAL_KEY="${CLUSTER_SERVICE_PRINCIPAL_KEY}"
CLUSTER_SERVICE_PRINCIPAL_OID="${CLUSTER_SERVICE_PRINCIPAL_OID}"
EOF

# setup dir
pushd ${OUTPUT_DIR}/deploy
# boot system
${OUTPUT_DIR}/deploy/boot.sh
# entering deployment environment
display_progress "Leaving deployment environment"
# do explicit login
az logout
# all done
popd
