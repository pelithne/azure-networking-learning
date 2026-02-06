#!/bin/bash
# Module 4: VPN Gateway - Deployment Script

set -e

RESOURCE_GROUP="rg-learn-vpn-gateway"
LOCATION="eastus2"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Module 4: VPN Gateway (P2S)${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: VPN Gateway takes 30-45 minutes to deploy!${NC}"
echo ""

if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter VM admin password:${NC}"
read -s ADMIN_PASSWORD
echo ""

# Check for root certificate
echo -e "${YELLOW}Do you have a root certificate for P2S VPN?${NC}"
echo "If you generated one with OpenSSL, paste the Base64 data."
echo "Or press Enter to skip (you can add it later in the portal)."
echo ""
read -p "Root cert Base64 (or Enter to skip): " ROOT_CERT_DATA

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}Resource group created${NC}"

echo ""
echo -e "${YELLOW}Starting deployment...${NC}"
echo "This will take 30-45 minutes. Go get some coffee! ☕"
echo ""
echo "Deploying:"
echo "  - Virtual Network with GatewaySubnet"
echo "  - VPN Gateway (VpnGw1)"
echo "  - Test VM (no public IP)"
echo ""

DEPLOYMENT_NAME="deploy-vpn-gateway-$(date +%Y%m%d-%H%M%S)"

if [ -n "$ROOT_CERT_DATA" ]; then
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --template-file main.bicep \
        --parameters \
            adminPassword="$ADMIN_PASSWORD" \
            vpnClientRootCertData="$ROOT_CERT_DATA" \
        --output none
else
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --template-file main.bicep \
        --parameters \
            adminPassword="$ADMIN_PASSWORD" \
        --output none
fi

echo -e "${GREEN}Deployment completed!${NC}"
echo ""

GATEWAY_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.gatewayPublicIp.value -o tsv)
VM_IP=$(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" \
    --query properties.outputs.vmPrivateIp.value -o tsv)

echo -e "${YELLOW}Deployment Outputs:${NC}"
echo "Gateway Public IP: $GATEWAY_IP"
echo "VM Private IP: $VM_IP"
echo "VPN Client Pool: 172.16.0.0/24"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Download VPN client:"
echo "   az network vnet-gateway vpn-client generate \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --name vpn-gw-azure \\"
echo "     --processor-architecture Amd64"
echo ""
echo "2. Extract and install the VPN client"
echo "3. Connect to VPN"
echo "4. Test: ping $VM_IP"
echo ""
echo -e "Cleanup: ${YELLOW}./cleanup.sh${NC}"
