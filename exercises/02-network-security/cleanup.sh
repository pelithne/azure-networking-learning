#!/bin/bash
# Module 2: Network Security - Cleanup Script

set -e

RESOURCE_GROUP="rg-learn-network-security"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}Cleanup: Module 2 Resources${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""

if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${GREEN}Resource group '${RESOURCE_GROUP}' does not exist.${NC}"
    exit 0
fi

echo -e "${YELLOW}Resources to be deleted:${NC}"
az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Type:type}" --output table
echo ""

read -p "Delete these resources? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo -e "${YELLOW}Deleting resource group...${NC}"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo -e "${GREEN}Deletion initiated (running in background).${NC}"
