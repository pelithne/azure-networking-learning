#!/bin/bash
set -e
RESOURCE_GROUP="rg-learn-dns"
LOCATION="eastus2"
echo "Module 8: DNS & Name Resolution"
read -s -p "VM password: " ADMIN_PASSWORD && echo ""
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o none
az deployment group create -g "$RESOURCE_GROUP" --template-file main.bicep \
    --parameters adminPassword="$ADMIN_PASSWORD" -o none
VM_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n main \
    --query properties.outputs.vmPublicIp.value -o tsv 2>/dev/null || echo "check portal")
echo "VM IP: $VM_IP"
echo "Test: ssh azureuser@$VM_IP 'nslookup vm-dns-test.contoso.internal'"
