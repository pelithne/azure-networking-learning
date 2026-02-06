#!/bin/bash
az group delete -n "rg-learn-dns" --yes --no-wait 2>/dev/null && echo "Deleting..."
