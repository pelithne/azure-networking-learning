// ============================================================================
// Parameters for Module 1: Virtual Network Fundamentals
// ============================================================================
// This parameter file configures the deployment for learning purposes.
// Adjust values as needed for your environment.
// ============================================================================

using '../main.bicep'

// The Azure region to deploy to
// TIP: Choose a region close to you for lower latency during testing
param location = 'swedencentral'

// Environment identifier - used in resource naming
param environmentName = 'learn'

// VM credentials
// SECURITY NOTE: In production, use Key Vault references or secure parameters
param adminUsername = 'azureuser'

// You'll be prompted for this during deployment
// Requirements: 12+ chars, uppercase, lowercase, number, special char
// Example: LearnAzure123!
param adminPassword = ''  // Will prompt during deployment for security

// Virtual Network address space
// CIDR: 10.0.0.0/16 = 65,536 IP addresses
// This is a common choice for learning and small-to-medium deployments
param vnetAddressSpace = '10.0.0.0/16'
