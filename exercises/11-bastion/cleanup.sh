#!/bin/bash
az group delete -n "rg-learn-bastion" --yes --no-wait && echo "Deleting..."
