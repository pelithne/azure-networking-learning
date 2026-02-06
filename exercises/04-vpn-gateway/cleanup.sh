#!/bin/bash
RESOURCE_GROUP="rg-learn-vpn-gateway"
echo "⚠️  VPN Gateway deletion takes 15-20 minutes."
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    read -p "Delete resource group ${RESOURCE_GROUP}? (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && az group delete --name "$RESOURCE_GROUP" --yes --no-wait
    echo "Deletion initiated (background)."
else
    echo "Resource group does not exist."
fi
