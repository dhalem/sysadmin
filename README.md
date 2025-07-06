# System Administration Ansible Repository

This repository contains Ansible playbooks and roles for managing system administration tasks, with a focus on monitoring infrastructure using Uptime Kuma.

## Repository Structure

Following Ansible best practices, this repository is organized as follows:

```
.
├── production.yml              # Production inventory
├── development.yml             # Development inventory (create as needed)
├── test.yml                   # Test inventory (create as needed)
├── requirements.txt           # Python dependencies
├── kuma-api-key.txt          # Kuma API key reference
├── group_vars/               # Variables for groups
│   ├── all/                 # Variables for all hosts
│   ├── kuma_monitors/       # Variables for monitoring group
│   │   └── kuma.yml        # Kuma-specific configuration
│   └── network_infrastructure/ # Variables for network devices
│       ├── main.yml        # Network device configuration
│       └── vault.yml       # Encrypted network credentials
├── host_vars/               # Variables for specific hosts (create as needed)
├── plays/                   # Playbooks directory
│   ├── ansible.cfg         # Ansible configuration
│   ├── site.yml           # Master playbook
│   ├── kuma-monitor-deploy.yml  # Legacy playbook (deprecated)
│   ├── test-connection.yml # Connection testing
│   ├── test-pfsense.yml   # pfSense connectivity testing
│   └── test-unifi.yml     # UniFi controller testing
└── roles/                  # Roles directory
    ├── requirements.yml    # External role dependencies
    ├── external/          # External roles from Galaxy
    └── internal/          # Custom internal roles
        └── kuma-monitoring/  # Uptime Kuma monitoring role
            ├── tasks/
            ├── templates/
            ├── defaults/
            ├── handlers/
            ├── vars/
            ├── meta/
            └── README.md
```

## Prerequisites

1. **Ansible Environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **External Dependencies**:
   ```bash
   ansible-galaxy install -r roles/requirements.yml
   ```

3. **Uptime Kuma Server**: Running on `networkbot:3001`

4. **SSH Access**: Configured for target machines

5. **Network Infrastructure Access**:
   - pfSense Router at `192.168.2.1` (API access)
   - UniFi Controller at `networkbot:8443` (API access)

## Infrastructure Overview

This repository manages **15 devices** across **4 logical groups**:

### **kuma_monitors (8 hosts)**
- **tahoepi1, tahoepi2** - Raspberry Pi devices
- **plexvan** - Media server
- **networkbot** - Kuma monitoring server
- **arrbot, devbot, musicbot, videobot** - Service automation bots

### **synology_nas (2 hosts)**
- **forge, fortress** - Synology NAS devices

### **proxmox_hosts (3 hosts)**
- **prox1, prox2, prox3** - Proxmox virtualization hosts

### **network_infrastructure (2 devices)**
- **pfsense** - Router/Firewall at `192.168.2.1` (HTTP API)
- **unifi** - Network Controller at `networkbot:8443` (HTTP API)

## Quick Start

### 1. Set API Token
```bash
export KUMA_AUTH_TOKEN="uk1_k9-9wLQz_yPIWeZ7gslUpmaX8YtB68duHAybdRF3"
```

### 2. Deploy Monitoring to Single Host
```bash
cd plays
ansible-playbook site.yml --limit tahoepi1 -e kuma_auth_token=$KUMA_AUTH_TOKEN
```

### 3. Deploy to All Monitors
```bash
cd plays
ansible-playbook site.yml -e kuma_auth_token=$KUMA_AUTH_TOKEN
```

### 4. Deploy with Tags
```bash
cd plays
ansible-playbook site.yml --tags monitoring -e kuma_auth_token=$KUMA_AUTH_TOKEN
```

## Configuration

### Inventory Management

- **production.yml**: Production environment inventory
- Add machines to the `kuma_monitors` group to enable monitoring
- Create `development.yml` and `test.yml` for other environments

### Variable Hierarchy

Variables are organized following Ansible's precedence rules:

1. **Role defaults**: `roles/internal/kuma-monitoring/defaults/main.yml`
2. **Group variables**: `group_vars/kuma_monitors/kuma.yml`
3. **Host variables**: `host_vars/hostname.yml` (create as needed)
4. **Playbook variables**: Set in playbooks or command line

### Kuma Configuration

Edit `group_vars/kuma_monitors/kuma.yml` to customize:

```yaml
---
# API Token (use environment variable or ansible-vault)
kuma_auth_token: "{{ lookup('env', 'KUMA_AUTH_TOKEN') }}"

# Custom settings
kuma_heartbeat_interval: 600  # 10 minutes
kuma_notification_ids: [1, 2] # Notification IDs from Kuma
```

## Security

### API Key Management

The Kuma API key is stored in `kuma-api-key.txt` for reference. In production:

1. **Environment Variables** (Recommended):
   ```bash
   export KUMA_AUTH_TOKEN="your-token-here"
   ```

2. **Ansible Vault** (Most Secure):
   ```bash
   ansible-vault create group_vars/kuma_monitors/vault.yml
   # Add: kuma_auth_token: "your-token-here"

   # Reference in kuma.yml:
   kuma_auth_token: "{{ vault_kuma_auth_token }}"
   ```

### SSH Keys

Ensure SSH key authentication is configured for all target hosts:
```bash
ssh-copy-id user@hostname
```

## Available Roles

### kuma-monitoring

Deploys Uptime Kuma push monitoring to target hosts.

**Features**:
- Creates push monitors in Kuma via API
- Deploys heartbeat scripts to target machines
- Configures cron jobs for regular heartbeats
- Supports customizable intervals and retry settings

**Variables** (see `roles/internal/kuma-monitoring/defaults/main.yml`):
- `kuma_server_url`: Kuma server URL
- `kuma_heartbeat_interval`: Heartbeat frequency in seconds
- `kuma_retry_interval`: Retry interval in seconds
- `kuma_max_retries`: Maximum retry attempts

## Troubleshooting

### Connection Issues
```bash
# Test SSH connectivity
cd plays
ansible-playbook test-connection.yml --limit hostname

# Test with verbose output
ansible-playbook site.yml -vvv --limit hostname
```

### Heartbeat Issues
```bash
# Check heartbeat logs on target machine
ssh hostname "tail -f /var/log/kuma-heartbeat.log"

# Test heartbeat manually
ssh hostname "sudo /usr/local/bin/kuma-heartbeat.sh"

# Check cron job
ssh hostname "crontab -l | grep kuma"
```

### API Issues
```bash
# Test API connectivity
curl -H "Authorization: Bearer $KUMA_AUTH_TOKEN" \
     http://networkbot:3001/api/status-page
```

## Development

### Adding New Roles

1. **Create role structure**:
   ```bash
   cd roles/internal
   ansible-galaxy init new-role-name
   ```

2. **Update site.yml** to include the new role

3. **Add role documentation** in `roles/internal/new-role-name/README.md`

### Testing

1. **Syntax checking**:
   ```bash
   cd plays
   ansible-playbook site.yml --syntax-check
   ```

2. **Dry run**:
   ```bash
   cd plays
   ansible-playbook site.yml --check --diff
   ```

## Best Practices Applied

This repository follows Ansible best practices:

- ✅ **Directory Structure**: Standard Ansible layout
- ✅ **Environment Separation**: Multiple inventory files
- ✅ **Variable Organization**: Hierarchical variable structure
- ✅ **Role Modularity**: Single-purpose roles
- ✅ **External Dependencies**: Managed via requirements.yml
- ✅ **Security**: Vault-ready for sensitive data
- ✅ **Documentation**: Comprehensive README and role docs
- ✅ **Configuration**: Centralized ansible.cfg

## References

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Uptime Kuma Ansible Collection](https://github.com/lucasheld/ansible-uptime-kuma)
- [Sample Ansible Setup](https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html)
