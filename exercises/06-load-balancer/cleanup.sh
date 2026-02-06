#!/bin/bash
RESOURCE_GROUP="rg-learn-load-balancer"
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    read -p "Delete resource group ${RESOURCE_GROUP}? (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && az group delete --name "$RESOURCE_GROUP" --yes --no-wait
    echo "Deletion initiated."
else
    echo "Resource group does not exist."
fi
