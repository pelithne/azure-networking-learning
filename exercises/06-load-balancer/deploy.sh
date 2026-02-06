#!/bin/bash
set -e
RESOURCE_GROUP="rg-learn-load-balancer"
LOCATION="eastus2"

echo "========================================"
echo "Module 6: Azure Load Balancer"
echo "========================================"

if ! az account show &> /dev/null; then
    echo "Error: Not logged in"
    exit 1
fi

read -s -p "Enter VM admin password: " ADMIN_PASSWORD
echo ""

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo "Resource group created"

echo "Deploying (5 VMs, 2 Load Balancers)..."
echo "This takes 5-8 minutes."

DEPLOYMENT_NAME="deploy-lb-$(date +%Y%m%d-%H%M%S)"
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters adminPassword="$ADMIN_PASSWORD" \
    --output none

echo "Deployment completed!"

PUBLIC_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.publicLbIp.value -o tsv)
INTERNAL_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.internalLbIp.value -o tsv)

echo ""
echo "Public LB IP: $PUBLIC_IP"
echo "Internal LB IP: $INTERNAL_IP"
echo ""
echo "Test commands:"
echo "  curl http://$PUBLIC_IP           # Test public LB"
echo "  ssh -p 50001 azureuser@$PUBLIC_IP  # SSH to vm-web-1"
echo "  ssh -p 50002 azureuser@$PUBLIC_IP  # SSH to vm-web-2"
echo ""
echo "From web VM, test internal LB:"
echo "  curl http://$INTERNAL_IP:8080"
echo ""
echo "Cleanup: ./cleanup.sh"
