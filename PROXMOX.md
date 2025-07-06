# Proxmox VM Automation and Network Segmentation Plan

## Executive Summary

This document outlines a comprehensive plan to:
1. **Migrate existing VMs to dedicated subnets** for better network segmentation
2. **Implement automated VM provisioning** using Ansible and Proxmox APIs
3. **Automate DHCP reservations and DNS record management** for seamless VM deployment
4. **Create standardized VM templates** with cloud-init for rapid deployment

## Current State Analysis

### Proxmox Cluster Configuration
- **Hosts**: prox1 (192.168.2.253), prox2 (192.168.2.254), prox3 (192.168.2.245)
- **Active VMs**: 7 VMs currently running on 192.168.2.0/24 subnet
- **Storage**: Local LVM-thin + shared CIFS from Synology NAS
- **Monitoring**: Comprehensive Kuma monitoring already deployed

### Current Network Layout
```
192.168.1.0/24  - Tahoe Pi devices
192.168.2.0/24  - Main infrastructure (Proxmox hosts + all VMs)
192.168.8.0/24  - Plex subnet
192.168.10.0/24 - IoT VLAN
192.168.200.0/24 - OpenVPN
```

### Existing VMs and Current IPs
| VM | Host | Current IP | Purpose |
|----|------|------------|---------|
| arrbot | prox3 | 192.168.2.221 | Media automation |
| musicbot | prox2 | 192.168.2.222 | Music services |
| networkbot | prox3 | 192.168.2.225 | Network monitoring |
| videobot | prox3 | 192.168.2.226 | Video processing |
| devbot | prox1 | 192.168.2.249 | Development |
| winbot | prox2 | N/A | Windows VM |
| letmeknowbot | prox3 | N/A | Notification service |

## Proposed Network Segmentation

### New Subnet Architecture
```
192.168.2.0/24  - Infrastructure (Proxmox hosts, pfSense, switches)
192.168.3.0/24  - Development VMs (devbot, test VMs)
192.168.4.0/24  - Production Services (networkbot, monitoring)
192.168.5.0/24  - Media Services (arrbot, musicbot, videobot)
192.168.6.0/24  - Utility/Testing (temporary VMs, experiments)
```

### Proposed VM Migration Plan
| VM | Current Subnet | Target Subnet | New IP Range |
|----|----------------|---------------|--------------|
| devbot | 192.168.2.0/24 | 192.168.3.0/24 | 192.168.3.10 |
| networkbot | 192.168.2.0/24 | 192.168.4.0/24 | 192.168.4.10 |
| arrbot | 192.168.2.0/24 | 192.168.5.0/24 | 192.168.5.10 |
| musicbot | 192.168.2.0/24 | 192.168.5.0/24 | 192.168.5.11 |
| videobot | 192.168.2.0/24 | 192.168.5.0/24 | 192.168.5.12 |
| winbot | 192.168.2.0/24 | 192.168.6.0/24 | 192.168.6.10 |
| letmeknowbot | 192.168.2.0/24 | 192.168.4.0/24 | 192.168.4.11 |

## Implementation Plan

### Phase 1: Infrastructure Preparation (Week 1)

#### 1.1 Network Infrastructure Setup
**Prerequisites**: Access to pfSense/UniFi controller

- [ ] **Create VLANs on pfSense**:
  - VLAN 3: 192.168.3.0/24 (Development)
  - VLAN 4: 192.168.4.0/24 (Production)
  - VLAN 5: 192.168.5.0/24 (Media)
  - VLAN 6: 192.168.6.0/24 (Utility)

- [ ] **Configure DHCP Scopes**:
  - 192.168.3.1-192.168.3.200 (Development)
  - 192.168.4.1-192.168.4.200 (Production)
  - 192.168.5.1-192.168.5.200 (Media)
  - 192.168.6.1-192.168.6.200 (Utility)

- [ ] **Setup DNS Zones**:
  - dev.local (192.168.3.0/24)
  - prod.local (192.168.4.0/24)
  - media.local (192.168.5.0/24)
  - util.local (192.168.6.0/24)

- [ ] **Configure Firewall Rules**:
  - Inter-VLAN communication rules
  - Internet access policies
  - Management access from 192.168.2.0/24

#### 1.2 Proxmox VLAN Bridge Configuration
**Target**: All Proxmox hosts (prox1, prox2, prox3)

- [ ] **Create VLAN-aware bridges on each Proxmox host**:
  ```bash
  # Add to /etc/network/interfaces on each host
  auto vmbr3
  iface vmbr3 inet manual
      bridge-ports eno1.3
      bridge-stp off
      bridge-fd 0
      bridge-vlan-aware yes

  auto vmbr4
  iface vmbr4 inet manual
      bridge-ports eno1.4
      bridge-stp off
      bridge-fd 0
      bridge-vlan-aware yes

  auto vmbr5
  iface vmbr5 inet manual
      bridge-ports eno1.5
      bridge-stp off
      bridge-fd 0
      bridge-vlan-aware yes

  auto vmbr6
  iface vmbr6 inet manual
      bridge-ports eno1.6
      bridge-stp off
      bridge-fd 0
      bridge-vlan-aware yes
  ```

#### 1.3 Ansible Collection Setup
- [ ] **Install required Ansible collections**:
  ```bash
  ansible-galaxy collection install community.general
  ansible-galaxy collection install community.libvirt
  ```

- [ ] **Configure Proxmox API access**:
  - Create dedicated API user for Ansible
  - Generate API tokens for secure access
  - Test connectivity from Ansible controller

### Phase 2: VM Template Creation (Week 1-2)

#### 2.1 Base Template Creation
- [ ] **Create standardized Ubuntu 24.04 LTS template**:
  - Cloud-init enabled
  - SSH key pre-configured
  - Standard packages (curl, wget, git, docker, tailscale)
  - Ansible user with sudo access
  - Tailscale client pre-installed

- [ ] **Create Debian 12 template** (alternative option)
- [ ] **Create Windows Server template** (for Windows VMs)

#### 2.2 Cloud-Init Configuration
- [ ] **Create cloud-init snippets directory on each Proxmox host**
- [ ] **Develop standardized cloud-init templates**:
  - Network configuration
  - User setup
  - SSH key injection
  - Package installation
  - Service configuration

### Phase 3: Automation Framework Development (Week 2-3)

#### 3.1 Ansible Role Development
- [ ] **Create `proxmox-vm-provisioning` role**:
  ```
  roles/
  └── proxmox-vm-provisioning/
      ├── tasks/
      │   ├── main.yml
      │   ├── create-vm.yml
      │   ├── configure-network.yml
      │   ├── setup-dhcp.yml
      │   └── update-dns.yml
      ├── templates/
      │   ├── cloud-init.yml.j2
      │   └── vm-config.json.j2
      ├── vars/
      │   └── main.yml
      └── defaults/
          └── main.yml
  ```

#### 3.2 Core Automation Components

**3.2.1 VM Creation Module**
```yaml
# Example VM creation task
- name: Create VM from template
  community.general.proxmox_kvm:
    api_host: "{{ proxmox_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    name: "{{ vm_name }}"
    template: "{{ vm_template }}"
    storage: "{{ vm_storage | default('local-lvm') }}"
    memory: "{{ vm_memory | default(4096) }}"
    cores: "{{ vm_cores | default(2) }}"
    net:
      net0: "virtio,bridge={{ vm_bridge }},tag={{ vm_vlan }}"
    ciuser: "{{ cloud_init_user }}"
    cipassword: "{{ cloud_init_password }}"
    sshkeys: "{{ ssh_public_key }}"
    ipconfig:
      ipconfig0: "ip={{ vm_ip }}/24,gw={{ vm_gateway }}"
    state: present
```

**3.2.2 DHCP Reservation Module**
```yaml
# DHCP reservation via pfSense API
- name: Create DHCP reservation
  uri:
    url: "https://{{ pfsense_host }}/api/v1/services/dhcpd/static_mapping"
    method: POST
    headers:
      Authorization: "Bearer {{ pfsense_api_token }}"
    body_format: json
    body:
      interface: "{{ dhcp_interface }}"
      mac: "{{ vm_mac_address }}"
      ipaddr: "{{ vm_ip }}"
      hostname: "{{ vm_hostname }}"
      description: "{{ vm_description }}"
```

**3.2.3 DNS Record Module**
```yaml
# DNS record creation via pfSense API
- name: Create DNS A record
  uri:
    url: "https://{{ pfsense_host }}/api/v1/services/unbound/host_override"
    method: POST
    headers:
      Authorization: "Bearer {{ pfsense_api_token }}"
    body_format: json
    body:
      host: "{{ vm_hostname }}"
      domain: "{{ dns_domain }}"
      ip: "{{ vm_ip }}"
      description: "Automated entry for {{ vm_name }}"
```

### Phase 4: Migration Implementation (Week 3-4)

#### 4.1 VM Migration Strategy
**Migration Order** (minimize downtime):
1. **devbot** (development VM - lowest impact)
2. **letmeknowbot** (utility service)
3. **winbot** (Windows VM)
4. **videobot** (media processing)
5. **arrbot** (media automation)
6. **musicbot** (music services)
7. **networkbot** (critical - migrate last)

#### 4.2 Migration Process per VM
```yaml
# Example migration playbook structure
- name: Migrate VM to new subnet
  hosts: localhost
  vars:
    vm_name: "{{ target_vm }}"
    new_subnet: "{{ target_subnet }}"
    new_ip: "{{ target_ip }}"
  tasks:
    - name: Shutdown VM gracefully
      proxmox_kvm:
        name: "{{ vm_name }}"
        state: stopped

    - name: Update VM network configuration
      proxmox_kvm:
        name: "{{ vm_name }}"
        net:
          net0: "virtio,bridge=vmbr{{ new_subnet_id }}"
        update: true

    - name: Create DHCP reservation
      include_tasks: create-dhcp-reservation.yml

    - name: Create DNS record
      include_tasks: create-dns-record.yml

    - name: Start VM
      proxmox_kvm:
        name: "{{ vm_name }}"
        state: started

    - name: Verify connectivity
      wait_for:
        host: "{{ new_ip }}"
        port: 22
        timeout: 300
```

### Phase 5: Automated Provisioning Framework (Week 4-5)

#### 5.1 VM Provisioning Playbook
```yaml
# Main VM provisioning playbook
- name: Provision new VM
  hosts: localhost
  vars_prompt:
    - name: vm_name
      prompt: "VM Name"
      private: false
    - name: vm_purpose
      prompt: "VM Purpose (dev/prod/media/util)"
      private: false
    - name: vm_template
      prompt: "Template (ubuntu-24.04/debian-12/windows-2022)"
      private: false
      default: "ubuntu-24.04"

  tasks:
    - name: Determine target subnet and Proxmox host
      set_fact:
        target_subnet: "{{ subnet_mapping[vm_purpose] }}"
        target_host: "{{ vm_placement_strategy(vm_purpose) }}"
        vm_ip: "{{ get_next_available_ip(target_subnet) }}"

    - name: Create VM
      include_role:
        name: proxmox-vm-provisioning
      vars:
        proxmox_host: "{{ target_host }}"
        vm_subnet: "{{ target_subnet }}"
```

#### 5.2 Self-Service VM Creation
**CLI Interface**:
```bash
# Quick VM creation commands
ansible-playbook create-vm.yml -e vm_name=testvm01 -e vm_purpose=dev
ansible-playbook create-vm.yml -e vm_name=monitoring02 -e vm_purpose=prod
ansible-playbook create-vm.yml -e vm_name=plex02 -e vm_purpose=media
```

#### 5.3 Integration with Existing Monitoring
- [ ] **Automatic Kuma monitor creation** for new VMs
- [ ] **Tailscale automatic enrollment** via cloud-init
- [ ] **SSH key distribution** via Ansible vault
- [ ] **Standard service deployment** (Docker, monitoring agents)

## Risk Assessment and Mitigation

### High-Risk Items
1. **Network connectivity loss during migration**
   - *Mitigation*: Maintain console access via Proxmox web UI
   - *Rollback*: Keep original network config backed up

2. **DNS/DHCP conflicts**
   - *Mitigation*: Pre-validate all IP assignments
   - *Testing*: Test on non-critical VMs first

3. **Service dependencies breaking**
   - *Mitigation*: Update all service configurations in lockstep
   - *Documentation*: Maintain dependency maps

### Medium-Risk Items
1. **Ansible automation failures**
   - *Mitigation*: Extensive testing in development environment
   - *Fallback*: Manual procedures documented

2. **Template corruption or misconfiguration**
   - *Mitigation*: Multiple template backups
   - *Validation*: Automated template testing

## Testing Strategy

### Pre-Migration Testing
1. **Create test VMs in each new subnet**
2. **Validate inter-subnet connectivity**
3. **Test DHCP/DNS automation with throwaway VMs**
4. **Verify Tailscale connectivity across subnets**

### Migration Testing
1. **Start with devbot (lowest impact)**
2. **Validate all services post-migration**
3. **Test backup/restore procedures**
4. **Confirm monitoring continues working**

### Post-Migration Validation
1. **Network performance testing**
2. **Service availability verification**
3. **Backup system validation**
4. **Security posture review**

## Timeline and Resource Requirements

### Estimated Timeline: 5 weeks
- **Week 1**: Infrastructure prep, VLAN setup
- **Week 2**: Template creation, initial automation
- **Week 3**: Migration of non-critical VMs
- **Week 4**: Migration of critical VMs
- **Week 5**: Automation refinement, documentation

### Resource Requirements
- **Network access**: pfSense admin access for VLAN/DHCP/DNS config
- **Proxmox access**: Root access to all three Proxmox hosts (already available)
- **Downtime windows**: 1-2 hours per VM migration (7 VMs total)
- **Testing environment**: Ability to create temporary test VMs

## Success Criteria

### Technical Objectives
- [ ] All VMs migrated to appropriate subnets
- [ ] Automated VM provisioning functional (< 10 minutes per VM)
- [ ] DHCP reservations and DNS records automated
- [ ] Network segmentation properly implemented
- [ ] No service disruption exceeding planned windows

### Operational Objectives
- [ ] New VM creation time reduced from hours to minutes
- [ ] Standardized VM configurations across environment
- [ ] Improved network security through segmentation
- [ ] Self-service VM provisioning capability
- [ ] Comprehensive documentation and runbooks

## Post-Implementation Maintenance

### Ongoing Tasks
1. **Template updates** (monthly security patches)
2. **DHCP scope management** (monitor utilization)
3. **DNS record cleanup** (remove obsolete entries)
4. **Network monitoring** (inter-VLAN traffic analysis)
5. **Automation improvements** (based on usage patterns)

### Monitoring and Alerting
- VM provisioning success/failure rates
- Network connectivity across subnets
- DHCP pool utilization
- Template deployment consistency

---

**Next Steps**:
1. Review and approve this plan
2. Schedule infrastructure preparation phase
3. Begin with VLAN configuration on pfSense
4. Proceed with phased implementation

**Questions for Review**:
1. Are the proposed subnets and IP ranges acceptable?
2. Is the migration order appropriate for your service priorities?
3. Are there any additional VMs or services to consider?
4. What is the preferred maintenance window for migrations?
