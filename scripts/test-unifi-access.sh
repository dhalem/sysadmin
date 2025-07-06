#!/bin/bash
# Script to test UniFi controller access with vault credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_PASS_FILE="$REPO_DIR/.vault_pass"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}UniFi Controller Access Test${NC}"
echo "===================================="

# Check if vault password file exists
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo -e "${YELLOW}Vault password file not found.${NC}"
    echo "Creating temporary vault password file..."
    read -s -p "Enter vault password: " VAULT_PASS
    echo
    echo "$VAULT_PASS" > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"
    echo -e "${GREEN}Vault password file created.${NC}"
fi

# Activate virtual environment
cd "$REPO_DIR"
source venv/bin/activate

# Test UniFi access
echo -e "${YELLOW}Testing UniFi controller access...${NC}"
ansible-playbook plays/test-unifi.yml -i production.yml --vault-password-file "$VAULT_PASS_FILE"

# Clean up vault password file
echo -e "${YELLOW}Cleaning up vault password file...${NC}"
rm -f "$VAULT_PASS_FILE"

echo -e "${GREEN}Test completed!${NC}"
