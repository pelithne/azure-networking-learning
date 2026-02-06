#!/bin/bash
set -e
echo "Module 12: Hub-Spoke Architecture"
echo "⚠️  This deploys Firewall + Bastion. Cost: ~\$2-3/hour"
read -s -p "VM password: " ADMIN_PASSWORD && echo ""
az group create -n "rg-learn-hubspoke" -l "eastus2" -o none
az deployment group create -g "rg-learn-hubspoke" --template-file main.bicep --parameters adminPassword="$ADMIN_PASSWORD" -o none
echo "Done! Connect via Bastion in Azure Portal"
echo "Cleanup with ./cleanup.sh"
