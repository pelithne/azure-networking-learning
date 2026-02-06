#!/bin/bash
# Module 2: Network Security - Deployment Script

set -e

RESOURCE_GROUP="rg-learn-network-security"
LOCATION="eastus2"
DEPLOYMENT_NAME="deploy-network-security-$(date +%Y%m%d-%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Module 2: Network Security (NSGs & ASGs)${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Check Azure CLI login
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    echo "Please run 'az login' first"
    exit 1
fi

# Get current IP for SSH rule
echo -e "${YELLOW}Detecting your public IP for SSH access...${NC}"
MY_IP=$(curl -s ifconfig.me)
echo -e "Your IP: ${GREEN}${MY_IP}${NC}"
echo ""

# Prompt for password
echo -e "${YELLOW}Enter a password for VM admin user:${NC}"
read -s ADMIN_PASSWORD
echo ""

if [ ${#ADMIN_PASSWORD} -lt 12 ]; then
    echo -e "${RED}Error: Password must be at least 12 characters${NC}"
    exit 1
fi

# Create resource group
echo -e "${YELLOW}Creating resource group: ${RESOURCE_GROUP}${NC}"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags environment=learn module=02-network-security \
    --output none

echo -e "${GREEN}Resource group created${NC}"
echo ""

# Deploy
echo -e "${YELLOW}Deploying Bicep template...${NC}"
echo "This will create:"
echo "  - 1 VNet with 3 subnets (web, app, db)"
echo "  - 3 NSGs (one per subnet)"
echo "  - 3 ASGs (webservers, appservers, dbservers)"
echo "  - 5 VMs across tiers"
echo ""
echo "Estimated deployment time: 5-8 minutes"
echo ""

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters \
        location="$LOCATION" \
        adminPassword="$ADMIN_PASSWORD" \
        allowedSshSourceIp="$MY_IP" \
    --output none

echo -e "${GREEN}Deployment completed!${NC}"
echo ""

# Get outputs
echo -e "${YELLOW}Deployment Outputs:${NC}"
echo "============================================"

WEB_PUBLIC_IP=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.webVmPublicIp.value -o tsv)

echo -e "Web VM Public IP: ${GREEN}${WEB_PUBLIC_IP}${NC}"
echo ""

echo -e "${YELLOW}Private IPs:${NC}"
az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.privateIps.value

echo ""
echo -e "${YELLOW}Quick Tests:${NC}"
echo "1. Test HTTP to web tier:"
echo "   curl http://${WEB_PUBLIC_IP}"
echo ""
echo "2. SSH to web VM:"
echo "   ssh azureuser@${WEB_PUBLIC_IP}"
echo ""
echo "3. From web VM, test app tier:"
echo "   curl 10.1.2.4:8080"
echo ""
echo "4. View NSG rules:"
echo "   az network nsg rule list -g ${RESOURCE_GROUP} --nsg-name nsg-snet-web -o table"
echo ""
echo "============================================"
echo -e "${GREEN}Ready for Module 2 exercises!${NC}"
echo -e "When done, run: ${YELLOW}./cleanup.sh${NC}"
