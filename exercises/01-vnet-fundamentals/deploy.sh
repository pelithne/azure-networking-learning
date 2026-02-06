#!/bin/bash
# ============================================================================
# Module 1: Virtual Network Fundamentals - Deployment Script
# ============================================================================
# This script deploys the Azure resources for Module 1.
#
# Prerequisites:
# - Azure CLI installed and logged in (az login)
# - Subscription selected (az account set -s <subscription-id>)
# ============================================================================

set -e  # Exit on any error

# Configuration
RESOURCE_GROUP="rg-learn-vnet-fundamentals"
LOCATION="eastus2"
DEPLOYMENT_NAME="deploy-vnet-fundamentals-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Module 1: Virtual Network Fundamentals${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Check if logged in to Azure
echo -e "${YELLOW}Checking Azure CLI login status...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    echo "Please run 'az login' first"
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "Using subscription: ${GREEN}${SUBSCRIPTION}${NC}"
echo ""

# Prompt for password
echo -e "${YELLOW}Enter a password for the VM admin user:${NC}"
echo "(Requirements: 12+ chars, uppercase, lowercase, number, special char)"
echo "Example: LearnAzure123!"
read -s ADMIN_PASSWORD
echo ""

# Validate password length
if [ ${#ADMIN_PASSWORD} -lt 12 ]; then
    echo -e "${RED}Error: Password must be at least 12 characters${NC}"
    exit 1
fi

# Create resource group
echo -e "${YELLOW}Creating resource group: ${RESOURCE_GROUP}${NC}"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags environment=learn purpose=azure-networking-training module=01-vnet-fundamentals \
    --output none

echo -e "${GREEN}Resource group created${NC}"
echo ""

# Deploy the Bicep template
echo -e "${YELLOW}Deploying Bicep template...${NC}"
echo "This will create:"
echo "  - Virtual Network with 4 subnets"
echo "  - Network Security Group"
echo "  - Public IP Address"
echo "  - Network Interface"
echo "  - Virtual Machine"
echo ""

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file main.bicep \
    --parameters \
        location="$LOCATION" \
        environmentName="learn" \
        adminUsername="azureuser" \
        adminPassword="$ADMIN_PASSWORD" \
    --output none

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""

# Get outputs
echo -e "${YELLOW}Deployment Outputs:${NC}"
echo "============================================"

VNET_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.vnetName.value -o tsv)

VM_PRIVATE_IP=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.vmPrivateIp.value -o tsv)

VM_PUBLIC_IP=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.vmPublicIp.value -o tsv)

echo -e "VNet Name:       ${GREEN}${VNET_NAME}${NC}"
echo -e "VM Private IP:   ${GREEN}${VM_PRIVATE_IP}${NC}"
echo -e "VM Public IP:    ${GREEN}${VM_PUBLIC_IP}${NC}"
echo ""
echo -e "${YELLOW}Connect to VM:${NC}"
echo -e "  ssh azureuser@${VM_PUBLIC_IP}"
echo ""
echo -e "${YELLOW}View effective routes:${NC}"
echo "  az network nic show-effective-route-table \\"
echo "    --resource-group ${RESOURCE_GROUP} \\"
echo "    --name nic-vm-web --output table"
echo ""
echo -e "${YELLOW}List subnets:${NC}"
echo "  az network vnet subnet list \\"
echo "    --resource-group ${RESOURCE_GROUP} \\"
echo "    --vnet-name ${VNET_NAME} --output table"
echo ""
echo "============================================"
echo -e "${GREEN}Ready for Module 1 exercises!${NC}"
echo -e "When done, run: ${YELLOW}./cleanup.sh${NC}"
