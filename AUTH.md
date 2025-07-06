# Ansible Authentication Setup Guide

This guide covers the complete setup process for secure SSH key-based authentication across all infrastructure hosts.

## Overview

We'll implement a multi-layered authentication strategy:
1. **SSH Key-Based Authentication** (primary method)
2. **Ansible Vault** for sensitive credentials
3. **Security Hardening** with password auth disabled
4. **Dedicated Service User** (optional but recommended)

## Phase 1: SSH Key Generation and Deployment

### Step 1: Generate Dedicated Ansible SSH Key

```bash
# Generate ed25519 key (more secure than RSA)
ssh-keygen -t ed25519 -f ~/.ssh/ansible_automation -C "ansible-automation-$(whoami)-$(date +%Y%m%d)"

# Set proper permissions
chmod 600 ~/.ssh/ansible_automation
chmod 644 ~/.ssh/ansible_automation.pub
```

### Step 2: Deploy Keys to All Hosts

Create the deployment script:

```bash
cat > deploy-ansible-keys.sh << 'EOF'
#!/bin/bash

KEY_FILE="$HOME/.ssh/ansible_automation.pub"
HOSTS="tahoepi1 tahoepi2 plexvan networkbot arrbot devbot musicbot videobot forge fortress prox1 prox2 prox3"

if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Key file not found: $KEY_FILE"
    echo "Please run the key generation step first"
    exit 1
fi

echo "🔑 Deploying Ansible SSH key to all hosts..."
echo "📋 Hosts: $HOSTS"
echo ""

failed_hosts=""
successful_hosts=""

for host in $HOSTS; do
    echo -n "📡 Deploying to $host... "

    if ssh-copy-id -i "$KEY_FILE" "dhalem@$host" >/dev/null 2>&1; then
        echo "✅"
        successful_hosts="$successful_hosts $host"
    else
        echo "❌"
        failed_hosts="$failed_hosts $host"
    fi
done

echo ""
echo "📊 Deployment Summary:"
echo "✅ Successful: $(echo $successful_hosts | wc -w) hosts"
if [ -n "$successful_hosts" ]; then
    echo "   $successful_hosts"
fi

echo "❌ Failed: $(echo $failed_hosts | wc -w) hosts"
if [ -n "$failed_hosts" ]; then
    echo "   $failed_hosts"
    echo ""
    echo "🔧 For failed hosts, try manual deployment:"
    for host in $failed_hosts; do
        echo "   ssh-copy-id -i $KEY_FILE dhalem@$host"
    done
fi

echo ""
echo "🧪 Testing connectivity..."
if [ -n "$successful_hosts" ]; then
    for host in $successful_hosts; do
        echo -n "🔗 Testing $host... "
        if ssh -i "$HOME/.ssh/ansible_automation" -o ConnectTimeout=5 -o BatchMode=yes "dhalem@$host" "echo 'OK'" >/dev/null 2>&1; then
            echo "✅"
        else
            echo "❌"
        fi
    done
fi

echo ""
echo "🎯 Next steps:"
echo "1. Update Ansible configuration (see Phase 2)"
echo "2. Test with: ansible all -m ping"
echo "3. Proceed with security hardening"
EOF

chmod +x deploy-ansible-keys.sh
```

### Step 3: Run Key Deployment

```bash
# Deploy keys to all hosts
./deploy-ansible-keys.sh
```

## Phase 2: Ansible Configuration Update

### Step 1: Update Ansible Configuration

Edit `plays/ansible.cfg`:

```ini
[defaults]
inventory = ../production.yml
host_key_checking = False
deprecation_warnings = False
retry_files_enabled = False
roles_path = ../roles/internal:../roles/external
private_key_file = ~/.ssh/ansible_automation
remote_user = dhalem

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True
control_path_dir = ~/.ansible/cp
```

### Step 2: Update Production Inventory

Edit `production.yml` to include authentication settings:

```yaml
all:
  vars:
    ansible_user: dhalem
    ansible_ssh_private_key_file: ~/.ssh/ansible_automation
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  children:
    kuma_monitors:
      hosts:
        tahoepi1:
          ansible_host: tahoepi1
        tahoepi2:
          ansible_host: tahoepi2
        plexvan:
          ansible_host: plexvan
        networkbot:
          ansible_host: networkbot
        arrbot:
          ansible_host: arrbot
        devbot:
          ansible_host: devbot
        musicbot:
          ansible_host: musicbot
        videobot:
          ansible_host: videobot
      vars:
        kuma_server_url: http://networkbot:3001
        kuma_admin_username: admin
    synology_nas:
      hosts:
        forge:
          ansible_host: forge
        fortress:
          ansible_host: fortress
      vars:
        # NAS-specific settings if needed
        ansible_python_interpreter: /usr/bin/python3
    proxmox_hosts:
      hosts:
        prox1:
          ansible_host: prox1
        prox2:
          ansible_host: prox2
        prox3:
          ansible_host: prox3
      vars:
        # Proxmox might need root access for some operations
        # ansible_user: root  # uncomment if needed
```

### Step 3: Test Connectivity

```bash
cd plays

# Test connection to all hosts
ansible all -m ping

# Test specific groups
ansible kuma_monitors -m ping
ansible synology_nas -m ping
ansible proxmox_hosts -m ping

# Gather basic facts
ansible all -m setup -a "filter=ansible_hostname"
```

## Phase 3: Security Hardening

### Step 1: Create Security Hardening Role

```bash
cd roles/internal
ansible-galaxy init security-hardening
```

### Step 2: Security Hardening Tasks

Create `roles/internal/security-hardening/tasks/main.yml`:

```yaml
---
- name: Backup original SSH config
  copy:
    src: /etc/ssh/sshd_config
    dest: /etc/ssh/sshd_config.backup
    remote_src: yes
    backup: yes
  become: true

- name: Disable password authentication
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?PasswordAuthentication'
    line: 'PasswordAuthentication no'
    backup: yes
  become: true
  notify: restart sshd

- name: Disable challenge response authentication
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?ChallengeResponseAuthentication'
    line: 'ChallengeResponseAuthentication no'
  become: true
  notify: restart sshd

- name: Disable empty passwords
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?PermitEmptyPasswords'
    line: 'PermitEmptyPasswords no'
  become: true
  notify: restart sshd

- name: Ensure PubkeyAuthentication is enabled
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?PubkeyAuthentication'
    line: 'PubkeyAuthentication yes'
  become: true
  notify: restart sshd

- name: Create ansible automation user (optional)
  user:
    name: ansible
    shell: /bin/bash
    groups: sudo
    append: yes
    create_home: yes
    comment: "Ansible Automation User"
  become: true
  when: create_ansible_user | default(false)

- name: Configure passwordless sudo for ansible user
  lineinfile:
    path: /etc/sudoers.d/ansible
    line: 'ansible ALL=(ALL) NOPASSWD:ALL'
    create: yes
    mode: '0440'
    validate: 'visudo -cf %s'
  become: true
  when: create_ansible_user | default(false)

- name: Deploy ansible user SSH key
  authorized_key:
    user: ansible
    key: "{{ lookup('file', '~/.ssh/ansible_automation.pub') }}"
    state: present
  become: true
  when: create_ansible_user | default(false)
```

### Step 3: Add SSH Restart Handler

Create `roles/internal/security-hardening/handlers/main.yml`:

```yaml
---
- name: restart sshd
  service:
    name: sshd
    state: restarted
  become: true
```

### Step 4: Create Security Hardening Playbook

Create `plays/security-hardening.yml`:

```yaml
---
- name: Apply security hardening to all hosts
  hosts: all
  become: false
  vars:
    create_ansible_user: false  # Set to true if you want dedicated ansible user
  roles:
    - security-hardening
  tags:
    - security
    - hardening
```

### Step 5: Apply Security Hardening

```bash
cd plays

# Test the hardening playbook first
ansible-playbook security-hardening.yml --check --diff

# Apply security hardening
ansible-playbook security-hardening.yml

# Verify SSH service is running
ansible all -m service -a "name=sshd state=started" --become
```

## Phase 4: Network Infrastructure Authentication

Network infrastructure devices (pfSense and UniFi) require different authentication methods than standard Linux hosts.

### pfSense Router Configuration

**pfSense uses HTTP API authentication instead of SSH.**

#### Step 1: Enable pfSense API Access

1. **Access pfSense Web Interface**: Navigate to https://192.168.2.1
2. **System → Advanced → Admin Access**:
   - Enable "Secure Shell" if you want SSH backup method
   - Note: Primary method will be HTTP API
3. **System → User Manager**:
   - Create dedicated API user or use admin
   - Assign appropriate privileges

#### Step 2: Install pfSense Ansible Collection

```bash
cd /home/dhalem/pishit/sysadmin
source venv/bin/activate

# Install pfSense collection
ansible-galaxy collection install pfsensible.core

# Add to requirements
echo "pfsensible.core" >> roles/requirements.yml
```

#### Step 3: Test pfSense Connectivity

Create `plays/test-pfsense.yml`:

```yaml
---
- name: Test pfSense connectivity
  hosts: pfsense
  gather_facts: no
  vars:
    # These should be in vault
    ansible_httpapi_user: "{{ vault_pfsense_user }}"
    ansible_httpapi_pass: "{{ vault_pfsense_password }}"
  tasks:
    - name: Get system information
      pfsensible.core.pfsense_setup:
      register: pfsense_info

    - name: Display pfSense info
      debug:
        msg: |
          Hostname: {{ pfsense_info.pfsense_setup.system.hostname }}
          Version: {{ pfsense_info.pfsense_setup.system.version }}
          Platform: {{ pfsense_info.pfsense_setup.system.platform }}
```

### UniFi Controller Configuration

**UniFi Controller uses API authentication with local connection.**

#### Step 1: Install UniFi Ansible Collection

```bash
# Install UniFi collection
ansible-galaxy collection install community.general

# For advanced UniFi management, consider:
# ansible-galaxy collection install ui.unifi
```

#### Step 2: Configure UniFi API Access

1. **Access UniFi Controller**: Navigate to https://networkbot:8443
2. **Settings → Admins**:
   - Create dedicated API user or use existing admin
   - Note down username and password
3. **Advanced Features**:
   - Enable "Advanced Features" if not already enabled
   - This unlocks API functionality

#### Step 3: Test UniFi Connectivity

Create `plays/test-unifi.yml`:

```yaml
---
- name: Test UniFi Controller connectivity
  hosts: unifi
  gather_facts: no
  connection: local
  vars:
    # These should be in vault
    unifi_username: "{{ vault_unifi_username }}"
    unifi_password: "{{ vault_unifi_password }}"
    unifi_url: "{{ unifi_url }}"
    unifi_validate_certs: false
  tasks:
    - name: Get UniFi site information
      uri:
        url: "{{ unifi_url }}/api/self/sites"
        method: GET
        user: "{{ unifi_username }}"
        password: "{{ unifi_password }}"
        force_basic_auth: yes
        validate_certs: "{{ unifi_validate_certs }}"
      register: unifi_sites

    - name: Display UniFi sites
      debug:
        msg: "UniFi sites: {{ unifi_sites.json.data | length }} found"
```

### Step 4: Create Network Infrastructure Group Variables

Create `group_vars/network_infrastructure/main.yml`:

```yaml
---
# Network infrastructure common settings
network_monitoring_enabled: true

# pfSense specific settings
pfsense_api_timeout: 30
pfsense_backup_config: true

# UniFi specific settings
unifi_validate_certs: false
unifi_timeout: 30
unifi_backup_enabled: true
```

Create `group_vars/network_infrastructure/vault.yml`:

```bash
ansible-vault create group_vars/network_infrastructure/vault.yml
```

Add the following content:

```yaml
---
# pfSense credentials
vault_pfsense_user: "admin"
vault_pfsense_password: "your_pfsense_password"

# UniFi credentials
vault_unifi_username: "your_unifi_admin"
vault_unifi_password: "your_unifi_password"
```

## Phase 5: Credential Management with Ansible Vault

### Step 1: Create Vault Password File

```bash
# Create a secure vault password
openssl rand -base64 32 > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Add to environment
echo "export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible_vault_pass" >> ~/.bashrc
source ~/.bashrc
```

### Step 2: Create Encrypted Vault File

```bash
# Create encrypted vault file
ansible-vault create group_vars/all/vault.yml

# Add the following content (replace with actual values):
---
vault_kuma_auth_token: "uk1_k9-9wLQz_yPIWeZ7gslUpmaX8YtB68duHAybdRF3"
vault_ansible_become_pass: "your_sudo_password_if_needed"
```

### Step 3: Update Kuma Configuration

Edit `group_vars/kuma_monitors/kuma.yml`:

```yaml
---
# Kuma monitoring configuration for kuma_monitors group

# API authentication from vault
kuma_auth_token: "{{ vault_kuma_auth_token }}"

# Override default settings if needed
# kuma_heartbeat_interval: 600  # 10 minutes
# kuma_notification_ids: [1, 2]  # Discord and email notifications
```

### Step 4: Test Vault Integration

```bash
cd plays

# Test with vault
ansible-playbook site.yml --limit tahoepi1

# If you didn't set ANSIBLE_VAULT_PASSWORD_FILE:
ansible-playbook site.yml --limit tahoepi1 --ask-vault-pass
```

## Phase 5: Verification and Testing

### Step 1: Comprehensive Connectivity Test

Create `plays/test-auth.yml`:

```yaml
---
- name: Test authentication and basic functionality
  hosts: all
  gather_facts: yes
  tasks:
    - name: Test basic connectivity
      ping:

    - name: Check current user
      command: whoami
      register: current_user

    - name: Check sudo access (if needed)
      command: sudo whoami
      register: sudo_test
      when: ansible_become | default(false)

    - name: Display connection info
      debug:
        msg: |
          Host: {{ inventory_hostname }}
          User: {{ current_user.stdout }}
          SSH Key: {{ ansible_ssh_private_key_file | default('default') }}
          Python: {{ ansible_python_interpreter | default('auto') }}
```

### Step 2: Run Authentication Tests

```bash
cd plays

# Test authentication across all hosts
ansible-playbook test-auth.yml

# Test Kuma monitoring deployment
ansible-playbook site.yml --limit tahoepi1 --check

# Deploy monitoring to a test host
ansible-playbook site.yml --limit tahoepi1
```

### Step 3: Security Verification

```bash
# Verify password authentication is disabled
ansible all -m shell -a "grep '^PasswordAuthentication' /etc/ssh/sshd_config" --become

# Check SSH key authentication
ansible all -m shell -a "grep '^PubkeyAuthentication' /etc/ssh/sshd_config" --become

# Verify ansible user (if created)
ansible all -m shell -a "id ansible" --become --ignore-errors
```

## Troubleshooting

### Common Issues and Solutions

**1. SSH Connection Timeout**
```bash
# Test direct SSH
ssh -i ~/.ssh/ansible_automation dhalem@hostname

# Check SSH service
ansible hostname -m service -a "name=sshd state=started" --become --ask-pass
```

**2. Permission Denied**
```bash
# Verify key is deployed
ansible hostname -m shell -a "cat ~/.ssh/authorized_keys | grep ansible"

# Check key permissions
ls -la ~/.ssh/ansible_automation*
```

**3. Sudo Issues**
```bash
# Test sudo access
ansible hostname -m shell -a "sudo whoami" --ask-become-pass

# Check sudoers file
ansible hostname -m shell -a "sudo grep ansible /etc/sudoers.d/ansible" --become
```

**4. Vault Decryption Errors**
```bash
# Test vault decryption
ansible-vault view group_vars/all/vault.yml

# Edit vault file
ansible-vault edit group_vars/all/vault.yml
```

### Emergency Recovery

**If you're locked out after hardening:**

1. **Console Access**: Use physical/VM console to log in
2. **Re-enable Password Auth**: Edit `/etc/ssh/sshd_config`
3. **Restart SSH**: `sudo systemctl restart sshd`
4. **Fix Keys**: Manually add your key to `~/.ssh/authorized_keys`

## Security Best Practices

### Key Rotation

```bash
# Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/ansible_automation_new

# Deploy new key alongside old
./deploy-ansible-keys.sh  # modify script for new key

# Update Ansible config
# Remove old key after verification
```

### Monitoring and Auditing

```bash
# Monitor SSH connections
ansible all -m shell -a "tail -10 /var/log/auth.log | grep sshd" --become

# Check for failed login attempts
ansible all -m shell -a "grep 'Failed password' /var/log/auth.log | tail -5" --become
```

### Backup and Recovery

```bash
# Backup SSH configurations
ansible all -m fetch -a "src=/etc/ssh/sshd_config dest=backups/{{ inventory_hostname }}/" --become

# Backup authorized_keys
ansible all -m fetch -a "src=~/.ssh/authorized_keys dest=backups/{{ inventory_hostname }}/"
```

## Adding New Hosts

### Step 1: Add to Inventory

Edit `production.yml` to add the new host to the appropriate group:

```yaml
# Example: Adding a new bot server
kuma_monitors:
  hosts:
    # ... existing hosts
    newbot:
      ansible_host: newbot
      # Optional host-specific vars
      # ansible_user: differentuser
      # ansible_port: 2222

# Example: Adding a new NAS
synology_nas:
  hosts:
    # ... existing hosts
    newnas:
      ansible_host: newnas.local
      ansible_python_interpreter: /usr/bin/python3

# Example: Adding a new Proxmox host
proxmox_hosts:
  hosts:
    # ... existing hosts
    prox4:
      ansible_host: 192.168.1.100
```

### Step 2: Deploy SSH Key to New Host

```bash
# Method 1: Use the deployment script (update hosts list first)
# Edit deploy-ansible-keys.sh to include new host
./deploy-ansible-keys.sh

# Method 2: Deploy manually to specific host
ssh-copy-id -i ~/.ssh/ansible_automation.pub dhalem@newhost

# Method 3: Use Ansible (if password auth still enabled)
ansible-playbook -i "newhost," plays/deploy-ssh-key.yml --ask-pass
```

### Step 3: Create SSH Key Deployment Playbook (for new hosts)

Create `plays/deploy-ssh-key.yml`:

```yaml
---
- name: Deploy SSH key to new host
  hosts: all
  gather_facts: no
  tasks:
    - name: Deploy ansible automation SSH key
      authorized_key:
        user: "{{ ansible_user }}"
        key: "{{ lookup('file', '~/.ssh/ansible_automation.pub') }}"
        state: present
      tags: ssh_key

    - name: Test SSH key authentication
      ping:
      tags: test
```

### Step 4: Test New Host Connectivity

```bash
# Test connectivity to new host
ansible newhost -m ping

# Test with specific inventory
ansible -i "newhost," all -m ping --ask-pass  # if using password initially

# Gather facts from new host
ansible newhost -m setup -a "filter=ansible_*"
```

### Step 5: Apply Security Hardening

```bash
# Apply security hardening to new host
ansible-playbook security-hardening.yml --limit newhost

# Or apply to specific group
ansible-playbook security-hardening.yml --limit kuma_monitors
```

### Step 6: Deploy Services to New Host

```bash
# Deploy Kuma monitoring
ansible-playbook site.yml --limit newhost

# Deploy specific roles
ansible-playbook site.yml --limit newhost --tags monitoring
```

### Step 7: Verify New Host Setup

Create `plays/verify-new-host.yml`:

```yaml
---
- name: Verify new host setup
  hosts: "{{ target_host | default('all') }}"
  gather_facts: yes
  tasks:
    - name: Check SSH key authentication
      ping:

    - name: Verify SSH security settings
      shell: |
        grep "^PasswordAuthentication no" /etc/ssh/sshd_config &&
        grep "^PubkeyAuthentication yes" /etc/ssh/sshd_config
      register: ssh_security
      become: true

    - name: Check sudo access
      shell: sudo whoami
      register: sudo_check

    - name: Verify services (if deployed)
      shell: crontab -l | grep kuma || echo "No kuma cron found"
      register: services_check

    - name: Display verification results
      debug:
        msg: |
          Host: {{ inventory_hostname }}
          SSH Security: {{ 'OK' if ssh_security.rc == 0 else 'FAILED' }}
          Sudo Access: {{ sudo_check.stdout }}
          Services: {{ 'Deployed' if 'kuma' in services_check.stdout else 'Not deployed' }}
          OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          Python: {{ ansible_python_version }}
```

Run verification:

```bash
ansible-playbook verify-new-host.yml --limit newhost
```

### Step 8: Update Documentation

1. **Update this AUTH.md** with any host-specific requirements
2. **Update main README.md** with new host information
3. **Commit changes** to git repository

```bash
# Update deployment script if needed
vim deploy-ansible-keys.sh  # Add new host to HOSTS variable

# Commit inventory changes
git add production.yml
git commit -m "Add new host: newhost to kuma_monitors group"
git push
```

### New Host Checklist

Use this checklist when adding new hosts:

```markdown
- [ ] Host is accessible via SSH
- [ ] Added to appropriate group in production.yml
- [ ] SSH key deployed successfully
- [ ] Connectivity test passes (ansible ping)
- [ ] Security hardening applied
- [ ] Password authentication disabled
- [ ] Services deployed (monitoring, etc.)
- [ ] Verification playbook passes
- [ ] Documentation updated
- [ ] Changes committed to git
```

### Automated New Host Setup Script

Create `add-new-host.sh`:

```bash
#!/bin/bash

HOST="$1"
GROUP="$2"
IP="$3"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <hostname> <group> [ip_address]"
    echo "Groups: kuma_monitors, synology_nas, proxmox_hosts"
    exit 1
fi

echo "🚀 Adding new host: $HOST to group: $GROUP"

# 1. Test initial connectivity
echo "📡 Testing initial connectivity..."
if ! ping -c 1 "$HOST" >/dev/null 2>&1; then
    echo "❌ Cannot reach $HOST"
    exit 1
fi

# 2. Deploy SSH key
echo "🔑 Deploying SSH key..."
if ! ssh-copy-id -i ~/.ssh/ansible_automation.pub "dhalem@$HOST"; then
    echo "❌ Failed to deploy SSH key"
    exit 1
fi

# 3. Add to inventory (manual step reminder)
echo "📝 Please add the following to production.yml under $GROUP:"
echo "    $HOST:"
echo "      ansible_host: ${IP:-$HOST}"

read -p "Press Enter after updating inventory..."

# 4. Test with Ansible
echo "🧪 Testing Ansible connectivity..."
if ! ansible "$HOST" -m ping; then
    echo "❌ Ansible connectivity failed"
    exit 1
fi

# 5. Apply security hardening
echo "🔒 Applying security hardening..."
ansible-playbook plays/security-hardening.yml --limit "$HOST"

# 6. Deploy services
echo "⚙️  Deploying services..."
ansible-playbook plays/site.yml --limit "$HOST"

# 7. Verify setup
echo "✅ Verifying setup..."
ansible-playbook plays/verify-new-host.yml --limit "$HOST"

echo ""
echo "🎉 Host $HOST successfully added!"
echo "📋 Don't forget to:"
echo "   - Commit inventory changes to git"
echo "   - Update documentation if needed"
echo "   - Add to deploy-ansible-keys.sh for future use"
```

Make it executable:

```bash
chmod +x add-new-host.sh
```

### Usage Examples

```bash
# Add a new bot server
./add-new-host.sh alertbot kuma_monitors

# Add a new NAS with specific IP
./add-new-host.sh backup-nas synology_nas 192.168.1.200

# Add a new Proxmox host
./add-new-host.sh prox4 proxmox_hosts 192.168.1.104
```

### Adding Network Infrastructure Devices

Network devices require special handling due to their unique authentication methods.

#### Adding pfSense Routers

```yaml
# Add to network_infrastructure group in production.yml
pfsense2:
  ansible_host: 192.168.3.1
  ansible_user: admin
  ansible_connection: httpapi
  ansible_httpapi_host: 192.168.3.1
  ansible_httpapi_port: 443
  ansible_httpapi_use_ssl: true
  ansible_httpapi_validate_certs: false
  ansible_network_os: pfsense
```

Test connectivity:
```bash
# Test pfSense API
ansible pfsense2 -m pfsensible.core.pfsense_setup
```

#### Adding UniFi Controllers

```yaml
# Add to network_infrastructure group in production.yml
unifi2:
  ansible_host: controller2
  ansible_user: dhalem
  unifi_url: https://controller2:8443
  unifi_port: 8443
  ansible_connection: local
```

Test connectivity:
```bash
# Test UniFi API
ansible-playbook plays/test-unifi.yml --limit unifi2
```

## Next Steps

After completing this authentication setup:

1. **Deploy Monitoring**: Run the Kuma monitoring playbook
2. **Create Additional Roles**: Develop other system management roles
3. **Set up CI/CD**: Consider Ansible Tower/AWX for advanced management
4. **Documentation**: Update team documentation with new procedures
5. **Training**: Ensure team members understand the new authentication model

## Quick Reference

**Key Commands:**
```bash
# Test all connections
ansible all -m ping

# Test network infrastructure
ansible network_infrastructure -m ping
ansible pfsense -m pfsensible.core.pfsense_setup
ansible-playbook plays/test-unifi.yml --limit unifi

# Deploy Kuma monitoring
cd plays && ansible-playbook site.yml

# Security hardening (SSH hosts only)
ansible-playbook security-hardening.yml --limit '!network_infrastructure'

# Emergency password-based connection
ansible hostname -m ping --ask-pass

# Network device management
ansible pfsense -m pfsensible.core.pfsense_config_backup
ansible-playbook plays/network-backup.yml
```

**Key Files:**
- `~/.ssh/ansible_automation` - Private key
- `~/.ansible_vault_pass` - Vault password
- `plays/ansible.cfg` - Ansible configuration
- `group_vars/all/vault.yml` - Encrypted credentials
