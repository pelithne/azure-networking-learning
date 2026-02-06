#!/bin/bash
set -e
echo "Module 10: Routing & UDRs"
read -s -p "VM password: " ADMIN_PASSWORD && echo ""
az group create -n "rg-learn-routing" -l "eastus2" -o none
az deployment group create -g "rg-learn-routing" --template-file main.bicep --parameters adminPassword="$ADMIN_PASSWORD" -o none
echo "Done! Cleanup with ./cleanup.sh"
