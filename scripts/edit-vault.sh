#!/bin/bash
# Script to edit and encrypt the network infrastructure vault file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_FILE="$REPO_DIR/group_vars/network_infrastructure/vault.yml"
VENV_DIR="$REPO_DIR/venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Network Infrastructure Vault Editor${NC}"
echo "=================================================="

# Check if vault file exists
if [ ! -f "$VAULT_FILE" ]; then
    echo -e "${RED}Error: Vault file not found at $VAULT_FILE${NC}"
    exit 1
fi

# Check if mg editor is available
if ! command -v mg &> /dev/null; then
    echo -e "${RED}Error: mg editor not found. Please install it or use another editor.${NC}"
    echo "Available editors:"
    for editor in nano vim emacs; do
        if command -v $editor &> /dev/null; then
            echo "  - $editor"
        fi
    done
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}Error: Virtual environment not found at $VENV_DIR${NC}"
    exit 1
fi

# Show current status
echo -e "${YELLOW}Current vault file status:${NC}"
if head -1 "$VAULT_FILE" | grep -q "ANSIBLE_VAULT"; then
    echo "  Status: ENCRYPTED"
    echo "  Action: Will decrypt, edit, then re-encrypt"
    ENCRYPTED=true
else
    echo "  Status: UNENCRYPTED"
    echo "  Action: Will edit, then encrypt"
    ENCRYPTED=false
fi

echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Edit the vault file with your actual credentials"
echo "2. Replace CHANGE_ME with real passwords"
echo "3. Save and exit mg (Ctrl+X)"
echo "4. The script will automatically encrypt the file"
echo ""
read -p "Press Enter to continue..."

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Create backup
BACKUP_FILE="$VAULT_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$VAULT_FILE" "$BACKUP_FILE"
echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"

# Edit the file
if [ "$ENCRYPTED" = true ]; then
    echo -e "${YELLOW}Decrypting and opening for editing...${NC}"
    ansible-vault edit "$VAULT_FILE"
else
    echo -e "${YELLOW}Opening for editing...${NC}"
    mg "$VAULT_FILE"

    # Check if file was modified
    if [ ! -f "$VAULT_FILE" ]; then
        echo -e "${RED}Error: Vault file was deleted or not saved${NC}"
        exit 1
    fi

    # Check if still contains placeholder
    if grep -q "CHANGE_ME" "$VAULT_FILE"; then
        echo -e "${YELLOW}Warning: File still contains CHANGE_ME placeholder${NC}"
        read -p "Do you want to continue encrypting anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Encryption cancelled. File remains unencrypted.${NC}"
            exit 0
        fi
    fi

    # Encrypt the file
    echo -e "${YELLOW}Encrypting vault file...${NC}"
    ansible-vault encrypt "$VAULT_FILE"
fi

echo -e "${GREEN}Vault file updated successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test UniFi access:"
echo "   ansible-playbook plays/test-unifi.yml -i production.yml --ask-vault-pass"
echo ""
echo "2. Test pfSense access (when pfsensible.core is available):"
echo "   ansible-playbook plays/test-pfsense.yml -i production.yml --ask-vault-pass"
echo ""
echo -e "${GREEN}Backup file: $BACKUP_FILE${NC}"
