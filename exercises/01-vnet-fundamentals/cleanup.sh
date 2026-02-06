#!/bin/bash
# ============================================================================
# Module 1: Virtual Network Fundamentals - Cleanup Script
# ============================================================================
# This script removes all resources created for Module 1.
# Always run this when you're done to avoid unnecessary Azure charges.
# ============================================================================

set -e

RESOURCE_GROUP="rg-learn-vnet-fundamentals"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}Cleanup: Module 1 Resources${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${GREEN}Resource group '${RESOURCE_GROUP}' does not exist.${NC}"
    echo "Nothing to clean up."
    exit 0
fi

# Show what will be deleted
echo -e "${YELLOW}The following resource group will be deleted:${NC}"
echo -e "  ${RED}${RESOURCE_GROUP}${NC}"
echo ""
echo "This will delete ALL resources in the group:"
az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Type:type}" --output table
echo ""

# Confirm deletion
read -p "Are you sure you want to delete these resources? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting resource group...${NC}"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo -e "${GREEN}Deletion initiated.${NC}"
echo "The resource group is being deleted in the background."
echo "This may take a few minutes to complete."
echo ""
echo "To check status:"
echo "  az group show --name ${RESOURCE_GROUP} --query properties.provisioningState"
