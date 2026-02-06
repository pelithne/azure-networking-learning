#!/bin/bash
set -e
echo "Module 9: Azure Firewall"
echo "⚠️  Azure Firewall costs ~\$1/hour. Delete when done!"
read -s -p "VM password: " ADMIN_PASSWORD && echo ""
az group create -n "rg-learn-firewall" -l "eastus2" -o none
az deployment group create -g "rg-learn-firewall" --template-file main.bicep --parameters adminPassword="$ADMIN_PASSWORD" -o none
echo "Done! Cleanup with ./cleanup.sh"
