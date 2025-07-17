#!/bin/bash

# Generate secure credentials for Temporal PostgreSQL
# This script should be run locally and the output manually applied to postgres-secret.yaml

set -e

echo "Generating secure credentials for Temporal PostgreSQL..."

# Generate secure password
PASSWORD=$(openssl rand -base64 32)

# Base64 encode credentials
USERNAME_B64=$(echo -n "temporal" | base64)
PASSWORD_B64=$(echo -n "$PASSWORD" | base64)

echo ""
echo "Generated credentials (DO NOT COMMIT TO GIT):"
echo "Username: temporal"
echo "Password: $PASSWORD"
echo ""
echo "Base64 encoded values for postgres-secret.yaml:"
echo "username: $USERNAME_B64"
echo "password: $PASSWORD_B64"
echo "postgres-username: $USERNAME_B64"
echo "postgres-password: $PASSWORD_B64"
echo ""
echo "IMPORTANT: Replace the placeholder values in postgres-secret.yaml with these values"
echo "NEVER commit actual credentials to Git!"
