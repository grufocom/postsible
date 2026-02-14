#!/bin/bash
# Postsible Mailserver - Setup Script
# Installs Ansible and prepares the environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Postsible Mailserver - Setup"
echo "=========================================="
echo ""

# Parse arguments
REMOTE_MODE=false
REMOTE_HOST=""
REMOTE_USER="root"
INTERACTIVE=false
DOMAIN=""
MX_HOSTNAME=""
ADMIN_EMAIL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --remote)
            REMOTE_MODE=true
            REMOTE_HOST="$2"
            shift 2
            ;;
        --user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --hostname)
            MX_HOSTNAME="$2"
            shift 2
            ;;
        --admin-email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --remote <host>        Setup for remote deployment (IP or hostname)"
            echo "  --user <user>          Remote SSH user (default: root)"
            echo "  --domain <domain>      Primary mail domain (e.g., example.com)"
            echo "  --hostname <hostname>  Mail server hostname (e.g., mail.example.com)"
            echo "  --admin-email <email>  Admin email address"
            echo "  --interactive          Interactive mode (prompts for all values)"
            echo "  --help                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Interactive setup (recommended for first time)"
            echo "  $0 --interactive"
            echo ""
            echo "  # Quick setup with all parameters"
            echo "  $0 --remote 192.168.1.100 --domain example.com \\"
            echo "     --hostname mail.example.com --admin-email admin@example.com"
            echo ""
            echo "  # Local setup"
            echo "  $0 --domain example.com --hostname mail.example.com"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Interactive mode - ask for missing values
if [ "$INTERACTIVE" = true ] || [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}=== Mail Server Configuration ===${NC}"
    echo ""

    if [ -z "$REMOTE_HOST" ]; then
        read -p "Deploy to remote server? (y/n) [n]: " deploy_remote
        if [[ "$deploy_remote" =~ ^[Yy]$ ]]; then
            REMOTE_MODE=true
            read -p "Enter server IP or hostname: " REMOTE_HOST
            read -p "SSH user [$REMOTE_USER]: " input_user
            REMOTE_USER=${input_user:-$REMOTE_USER}
        fi
    fi

    if [ -z "$DOMAIN" ]; then
        read -p "Primary mail domain (e.g., example.com): " DOMAIN
    fi

    if [ -z "$MX_HOSTNAME" ]; then
        read -p "Mail server hostname (e.g., mail.$DOMAIN) [mail.$DOMAIN]: " MX_HOSTNAME
        MX_HOSTNAME=${MX_HOSTNAME:-mail.$DOMAIN}
    fi

    if [ -z "$ADMIN_EMAIL" ]; then
        read -p "Admin email address [admin@$DOMAIN]: " ADMIN_EMAIL
        ADMIN_EMAIL=${ADMIN_EMAIL:-admin@$DOMAIN}
    fi

    echo ""
    echo -e "${GREEN}Configuration Summary:${NC}"
    [ "$REMOTE_MODE" = true ] && echo "Deployment: Remote ($REMOTE_USER@$REMOTE_HOST)" || echo "Deployment: Local"
    echo "Domain: $DOMAIN"
    echo "Hostname: $MX_HOSTNAME"
    echo "Admin Email: $ADMIN_EMAIL"
    echo ""
    read -p "Continue with this configuration? (y/n) [y]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Validate required values
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain is required${NC}"
    echo "Use --domain <domain> or --interactive"
    exit 1
fi

if [ -z "$MX_HOSTNAME" ]; then
    MX_HOSTNAME="mail.$DOMAIN"
fi

if [ -z "$ADMIN_EMAIL" ]; then
    ADMIN_EMAIL="admin@$DOMAIN"
fi

echo ""

# Check if running as root (only for local mode)
if [ "$REMOTE_MODE" = false ] && [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root for local setup${NC}"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo -e "${RED}Error: Cannot detect OS${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS: $OS $VERSION${NC}"
echo ""

if [ "$REMOTE_MODE" = true ]; then
    echo -e "${YELLOW}Remote deployment mode${NC}"
    echo "Target host: $REMOTE_HOST"
    echo "SSH user: $REMOTE_USER"
    echo ""
fi

# Install Ansible
if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        apt update
        apt install -y ansible git python3-pip sshpass
    else
        echo -e "${RED}Error: Unsupported OS. This script supports Debian/Ubuntu only.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Ansible installed successfully!${NC}"
else
    echo -e "${GREEN}Ansible is already installed ($(ansible --version | head -n1))${NC}"
fi

echo ""

# Install required Ansible collections
echo "Installing Ansible collections..."
ansible-galaxy collection install community.general 2>/dev/null || true
ansible-galaxy collection install ansible.posix 2>/dev/null || true

echo ""

# SSH Key Management
if [ "$REMOTE_MODE" = true ]; then
    echo "Setting up SSH access to remote host..."

    # Generate SSH key if not exists
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo "Generating SSH key..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "ansible@postsible"
        echo -e "${GREEN}SSH key generated${NC}"
    fi

    # Test SSH connection
    echo "Testing SSH connection to $REMOTE_USER@$REMOTE_HOST..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes $REMOTE_USER@$REMOTE_HOST "echo 'SSH OK'" &> /dev/null; then
        echo -e "${GREEN}SSH connection successful (key-based auth)!${NC}"
    else
        echo -e "${YELLOW}SSH key-based authentication not configured${NC}"
        echo "Attempting to copy SSH key to remote host..."
        echo "You will be prompted for the password of $REMOTE_USER@$REMOTE_HOST"

        if command -v ssh-copy-id &> /dev/null; then
            ssh-copy-id -i ~/.ssh/id_ed25519.pub $REMOTE_USER@$REMOTE_HOST
        else
            echo -e "${YELLOW}ssh-copy-id not found. Manual setup required.${NC}"
            echo "Copy this key to $REMOTE_HOST:~/.ssh/authorized_keys:"
            cat ~/.ssh/id_ed25519.pub
            echo ""
            read -p "Press Enter after copying the key..."
        fi

        # Test again
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes $REMOTE_USER@$REMOTE_HOST "echo 'SSH OK'" &> /dev/null; then
            echo -e "${GREEN}SSH key successfully configured!${NC}"
        else
            echo -e "${RED}Warning: SSH connection still requires password${NC}"
            echo "You may need to configure SSH keys manually or use --ask-pass with ansible-playbook"
        fi
    fi
else
    # Local mode SSH setup
    echo "Checking SSH access..."
    if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
        echo "No SSH key found. Generating one..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "ansible@postsible"
        cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo -e "${GREEN}SSH key generated and added to authorized_keys${NC}"
    fi

    echo "Testing SSH connection to localhost..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@localhost "echo 'SSH OK'" &> /dev/null; then
        echo -e "${GREEN}SSH connection successful!${NC}"
    else
        echo -e "${YELLOW}Warning: SSH connection to localhost failed${NC}"
        echo "You may need to enable SSH or configure SSH keys manually"
    fi
fi

echo ""

# Create/Update inventory file
if [ "$REMOTE_MODE" = true ]; then
    echo "Creating inventory file for remote deployment..."
    cat > inventory/hosts.yml << EOF
---
# Postsible Inventory - Remote Deployment
# Generated by setup.sh on $(date)

mailservers:
  hosts:
    $MX_HOSTNAME:
      ansible_host: $REMOTE_HOST
      ansible_user: $REMOTE_USER
      ansible_python_interpreter: /usr/bin/python3

      # Server identification
      common_hostname: $MX_HOSTNAME

      # Uncomment if SSH password is needed:
      # ansible_ssh_pass: "{{ vault_ansible_ssh_pass }}"
      # Uncomment if sudo password is needed:
      # ansible_become_pass: "{{ vault_ansible_become_pass }}"
EOF
    echo -e "${GREEN}Inventory file created: inventory/hosts.yml${NC}"
else
    echo "Creating inventory file for local deployment..."
    REMOTE_HOST="localhost"
    cat > inventory/hosts.yml << EOF
---
# Postsible Inventory - Local Deployment
# Generated by setup.sh on $(date)

mailservers:
  hosts:
    $MX_HOSTNAME:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3

      # Server identification
      common_hostname: $MX_HOSTNAME
EOF
    echo -e "${GREEN}Inventory file created: inventory/hosts.yml${NC}"
fi

# Create vars.yml if it doesn't exist
if [ ! -f "inventory/group_vars/mailservers/vars.yml" ]; then
    echo "Creating vars.yml with your configuration..."
    cat > inventory/group_vars/mailservers/vars.yml << EOF
---
# Postsible Mailserver Configuration (Public)
# Sensitive data is in vault.yml (encrypted)
# Generated by setup.sh on $(date)

# Common Settings
common_timezone: "Europe/Vienna"
common_locales:
  - de_AT.UTF-8
  - en_US.UTF-8
common_default_locale: "de_AT.UTF-8"

# Mail Configuration
mail_primary_domain: "$DOMAIN"
mail_virtual_domains:
  - $DOMAIN
mail_admin_email: "$ADMIN_EMAIL"
mail_letsencrypt_email: "$ADMIN_EMAIL"
mail_ssl_cert_path: "/etc/letsencrypt/live/{{ mail_primary_domain }}"

mail_imap_port: 993
mail_smtp_port: 465

# MariaDB Settings (Non-Sensitive)
mariadb_database: "mailserver"
mariadb_user: "mailuser"
mariadb_host: "localhost"

# MariaDB Passwords (from Vault)
mariadb_root_password: "{{ vault_mariadb_root_password }}"
mariadb_password: "{{ vault_mariadb_password }}"

# Postfix Settings
postfix_myhostname: "{{ common_hostname }}"
postfix_mydomain: "{{ mail_primary_domain }}"
postfix_myorigin: "\$mydomain"
postfix_inet_interfaces: "all"
postfix_inet_protocols: "ipv4"

# Subaddressing (plus addressing)
postfix_recipient_delimiter: "+"

# Dovecot Settings
dovecot_mail_location: "maildir:/srv/imap/%d/%n/"
dovecot_protocols: "imap lmtp sieve"

# Rspamd Settings
rspamd_webui_enabled: true
rspamd_webui_password: "{{ vault_rspamd_webui_password }}"

# SnappyMail Settings
snappymail_domain: "{{ mail_primary_domain }}"
snappymail_admin_user: "admin"
snappymail_admin_password: "{{ vault_snappymail_admin_password }}"

# Infcloud Settings
infcloud_use_subdomain: false
infcloud_base_path: "/cal"
#infcloud_subdomain: "cal"  # Results in cal.{{ mail_primary_domain }}

# Localization
infcloud_language: "de_DE"  # Available: en_US, de_DE, fr_FR, etc.
infcloud_timezone: "Europe/Vienna"
infcloud_first_day_of_week: 1  # Monday

# Features
infcloud_enable_calendar: true
infcloud_enable_contacts: true
infcloud_enable_projects: false  # Tasks/TODOs (needs CalDAV VTODO support)

# Branding
infcloud_title: "My Company Calendar"
infcloud_logo_text: "{{ mail_primary_domain }}"

# Nginx Settings
nginx_worker_processes: "auto"
nginx_worker_connections: 1024

# UFW Firewall Settings
ufw_ssh_port: 22
ufw_ssh_trusted_ips:
  # Add your own IPs here:
  # - ip: "YOUR_HOME_IP"
  #   comment: "Home Office"
  # - ip: "YOUR_OFFICE_IP/24"
  #   comment: "Office Network"

ufw_enable_smtps: true   # Port 465 (some clients need SMTP over SSL)
ufw_enable_pop3s: false  # Port 995 (usually not needed)
ufw_rate_limit_smtp: false  # Set to true for SMTP rate limiting
ufw_logging_level: "low"

# Fail2ban Settings
fail2ban_bantime: 3600
fail2ban_findtime: 600
fail2ban_maxretry: 5
fail2ban_destemail: "{{ mail_admin_email }}"

# ESET ICAP Settings
eset_icap_enabled: false
eset_icap_host: "localhost"
eset_icap_port: 1344
EOF
    echo -e "${GREEN}Configuration file created: inventory/group_vars/mailservers/vars.yml${NC}"
fi

# Create example vault file if it doesn't exist
if [ ! -f "inventory/group_vars/mailservers/vault.yml" ]; then
    echo "Creating example vault file template..."
    cat > inventory/group_vars/mailservers/vault.yml.example << EOF
---
# Postsible Vault - Sensitive Data
# Copy this to vault.yml and encrypt with: ansible-vault encrypt vault.yml
# Or create directly with: ansible-vault create vault.yml

# Generate strong passwords with: openssl rand -base64 32

# MariaDB Passwords
vault_mariadb_root_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"
vault_mariadb_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"

# Rspamd WebUI Password
vault_rspamd_webui_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"

# SnappyMail Admin Password
vault_snappymail_admin_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"

# Optional: SSH/Sudo passwords for remote deployment
# vault_ansible_ssh_pass: "YOUR_SSH_PASSWORD"
# vault_ansible_become_pass: "YOUR_SUDO_PASSWORD"
EOF
    echo -e "${GREEN}Vault template created: inventory/group_vars/mailservers/vault.yml.example${NC}"
    echo -e "${YELLOW}Note: Copy and encrypt this file before deployment!${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=========================================="
echo ""
echo -e "${GREEN}✓${NC} Configuration created for: $DOMAIN"
echo -e "${GREEN}✓${NC} Hostname: $MX_HOSTNAME"
echo -e "${GREEN}✓${NC} Admin Email: $ADMIN_EMAIL"
if [ "$REMOTE_MODE" = true ]; then
    echo -e "${GREEN}✓${NC} Target: $REMOTE_USER@$REMOTE_HOST"
else
    echo -e "${GREEN}✓${NC} Target: Local deployment"
fi
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. ${YELLOW}Create encrypted vault file:${NC}"
echo "   cp inventory/group_vars/mailservers/vault.yml.example \\"
echo "      inventory/group_vars/mailservers/vault.yml"
echo "   # Edit the file and change all CHANGE_ME passwords"
echo "   ansible-vault encrypt inventory/group_vars/mailservers/vault.yml"
echo ""
echo "2. ${YELLOW}Configure DNS records for $DOMAIN:${NC}"
echo "   MX Record:  $DOMAIN → $MX_HOSTNAME (Priority: 10)"
echo "   A Record:   $MX_HOSTNAME → $REMOTE_HOST"
echo "   PTR Record: $REMOTE_HOST → $MX_HOSTNAME (Reverse DNS)"
echo "   SPF:        $DOMAIN TXT \"v=spf1 mx -all\""
echo "   SPF:        $MX_HOSTNAME TXT \"v=spf1 a -all\""
echo ""
echo "3. ${YELLOW}Test connection:${NC}"
echo "   ansible mailservers -m ping --ask-vault-pass"
echo ""
echo "4. ${YELLOW}Run deployment:${NC}"
echo "   ansible-playbook playbooks/site.yml --ask-vault-pass"
echo ""
echo "5. ${YELLOW}After deployment, add DKIM and DMARC records:${NC}"
echo "   DKIM: Check /root/dkim-dns-records.txt on the server"
echo "   DMARC: _dmarc.$DOMAIN TXT \"v=DMARC1; p=quarantine; rua=mailto:$ADMIN_EMAIL\""
echo ""
echo -e "${YELLOW}Important files created:${NC}"
echo "  • inventory/hosts.yml"
echo "  • inventory/group_vars/mailservers/vars.yml"
echo "  • inventory/group_vars/mailservers/vault.yml.example"
echo ""
echo "For more information, see README.md"
echo "=========================================="
