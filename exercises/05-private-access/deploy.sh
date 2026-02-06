#!/bin/bash
set -e

RESOURCE_GROUP="rg-learn-private-access"
LOCATION="eastus2"

echo "========================================"
echo "Module 5: Private Access (Private Endpoints)"
echo "========================================"
echo ""

if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure CLI"
    exit 1
fi

read -s -p "Enter VM admin password: " ADMIN_PASSWORD
echo ""

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo "Resource group created"

echo "Deploying... (~5 minutes)"

DEPLOYMENT_NAME="deploy-private-access-$(date +%Y%m%d-%H%M%S)"
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters adminPassword="$ADMIN_PASSWORD" \
    --output none

echo "Deployment completed!"
echo ""

VM_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.vmPublicIp.value -o tsv)
STORAGE_NAME=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.storageAccountName.value -o tsv)
PE_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.privateEndpointIp.value -o tsv)

echo "VM Public IP: $VM_IP"
echo "Storage Account: $STORAGE_NAME"
echo "Private Endpoint IP: $PE_IP"
echo ""
echo "Test commands (run from VM):"
echo "  ssh azureuser@$VM_IP"
echo "  nslookup ${STORAGE_NAME}.blob.core.windows.net"
echo "  # Should resolve to: $PE_IP"
echo ""
echo "Cleanup: ./cleanup.sh"
