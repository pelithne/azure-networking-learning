#!/bin/bash
set -e
echo "Module 16: Virtual WAN (Optional)"
echo "⚠️  WARNING: Virtual WAN costs ~\$2-5/hour minimum!"
read -p "Are you sure you want to deploy? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled"; exit 0; fi
az group create -n "rg-learn-vwan" -l "eastus2" -o none
az deployment group create -g "rg-learn-vwan" --template-file main.bicep -o none
echo "Done! DELETE IMMEDIATELY when finished with ./cleanup.sh"
