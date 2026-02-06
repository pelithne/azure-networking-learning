#!/bin/bash
# Module 3: VNet Peering - Deployment Script

set -e

RESOURCE_GROUP="rg-learn-vnet-peering"
LOCATION="eastus2"
DEPLOYMENT_NAME="deploy-vnet-peering-$(date +%Y%m%d-%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Module 3: VNet Peering${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter VM admin password:${NC}"
read -s ADMIN_PASSWORD
echo ""

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}Resource group created${NC}"

echo -e "${YELLOW}Deploying (3 VNets, 3 VMs, 4 peerings)...${NC}"
echo "Estimated time: 3-5 minutes"
echo ""

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters adminPassword="$ADMIN_PASSWORD" location="$LOCATION" \
    --output none

echo -e "${GREEN}Deployment completed!${NC}"
echo ""

HUB_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.hubPublicIp.value -o tsv)

echo -e "${YELLOW}VM IPs:${NC}"
az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.vmIps.value

echo ""
echo -e "${YELLOW}Peering Status:${NC}"
az network vnet peering list -g "$RESOURCE_GROUP" --vnet-name vnet-hub -o table

echo ""
echo -e "${YELLOW}Quick Tests:${NC}"
echo "1. SSH to hub: ssh azureuser@${HUB_IP}"
echo "2. From hub, ping spoke1: ping 10.1.1.4"
echo "3. From hub, ping spoke2: ping 10.2.1.4"
echo "4. SSH to spoke1: ssh azureuser@10.1.1.4"
echo "5. From spoke1, try ping spoke2: ping 10.2.1.4 (will FAIL - non-transitive!)"
echo ""
echo -e "${GREEN}Ready for Module 3 exercises!${NC}"
echo -e "Cleanup: ${YELLOW}./cleanup.sh${NC}"
