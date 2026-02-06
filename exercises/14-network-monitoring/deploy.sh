#!/bin/bash
set -e
echo "Module 14: Network Monitoring"
read -s -p "VM password: " ADMIN_PASSWORD && echo ""
az group create -n "rg-learn-monitoring" -l "eastus2" -o none
az deployment group create -g "rg-learn-monitoring" --template-file main.bicep --parameters adminPassword="$ADMIN_PASSWORD" -o none
echo "Done! Cleanup with ./cleanup.sh"
