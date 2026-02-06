#!/bin/bash
set -e
echo "Module 11: Azure Bastion"
echo "ℹ️  Bastion Standard SKU costs ~\$0.35/hour"
read -s -p "VM password: " ADMIN_PASSWORD && echo ""
az group create -n "rg-learn-bastion" -l "eastus2" -o none
az deployment group create -g "rg-learn-bastion" --template-file main.bicep --parameters adminPassword="$ADMIN_PASSWORD" -o none
echo "Done! Connect via: Azure Portal → VM → Connect → Bastion"
echo "Cleanup with ./cleanup.sh"
