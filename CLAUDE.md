# Claude Assistant Guidelines

## Vault Password File Management

- **NEVER remove `.vault_pass` file without explicit user permission**
- The vault password file is used for automated Ansible vault operations
- File is protected by .gitignore to prevent accidental commits
- Always ask before cleaning up or removing vault-related files

## Repository Structure

This is an Ansible-based system administration repository with:
- 15 managed devices across 4 groups
- Encrypted vault for sensitive credentials
- SSH key-based authentication for most hosts
- API-based authentication for network infrastructure

## Common Commands

### Testing Authentication
```bash
# Test all SSH hosts
ansible all -i production.yml -m ping --limit '!pfsense'

# Test UniFi controller
ansible-playbook plays/test-unifi.yml -i production.yml --vault-password-file .vault_pass
```

### Vault Operations
```bash
# Edit vault (uses script)
./scripts/edit-vault.sh

# Manual vault edit
ansible-vault edit group_vars/network_infrastructure/vault.yml --vault-password-file .vault_pass
```

### Monitoring Deployment
```bash
# Deploy Kuma monitoring
ansible-playbook plays/site.yml -e kuma_auth_token=$KUMA_AUTH_TOKEN --vault-password-file .vault_pass
```
