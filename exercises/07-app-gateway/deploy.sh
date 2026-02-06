#!/bin/bash
set -e
RESOURCE_GROUP="rg-learn-app-gateway"
LOCATION="eastus2"
echo "Module 7: Application Gateway (L7 Load Balancer)"
echo "⏱️  Deployment takes ~10-15 minutes"
if ! az account show &> /dev/null; then exit 1; fi
read -s -p "VM password: " ADMIN_PASSWORD && echo ""
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
DEPLOYMENT_NAME="deploy-appgw-$(date +%Y%m%d-%H%M%S)"
az deployment group create -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --template-file main.bicep --parameters adminPassword="$ADMIN_PASSWORD" --output none
echo "Done!"
PUBLIC_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.appGatewayPublicIp.value -o tsv)
echo "App Gateway IP: $PUBLIC_IP"
echo "Test: curl http://$PUBLIC_IP"
