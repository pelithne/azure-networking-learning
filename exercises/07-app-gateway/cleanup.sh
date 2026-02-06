#!/bin/bash
RESOURCE_GROUP="rg-learn-app-gateway"
[[ $(az group exists -n "$RESOURCE_GROUP") == "true" ]] && \
    read -p "Delete $RESOURCE_GROUP? (y/N): " c && [[ "$c" =~ ^[Yy]$ ]] && \
    az group delete -n "$RESOURCE_GROUP" --yes --no-wait && echo "Deleting..."
