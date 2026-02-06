#!/bin/bash
set -e
echo "Module 13: Global Load Balancing"
az group create -n "rg-learn-global-lb" -l "eastus2" -o none
az deployment group create -g "rg-learn-global-lb" --template-file main.bicep -o none
echo "Done! Cleanup with ./cleanup.sh"
