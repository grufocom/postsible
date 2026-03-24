#!/bin/bash
# Postsible Mailserver - Setup Script
# Installs Ansible and prepares the environment for multi-domain deployments

set -e

# ── Terminal color detection ───────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[1;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

print_header()  { printf "\n${BLUE}==========================================${NC}\n${BOLD}%s${NC}\n${BLUE}==========================================${NC}\n\n" "$1"; }
print_success() { printf "${GREEN}✓${NC} %s\n" "$1"; }
print_warning() { printf "${YELLOW}⚠ %s${NC}\n" "$1"; }
print_error()   { printf "${RED}✗ %s${NC}\n" "$1"; }
print_info()    { printf "${BLUE}ℹ${NC} %s\n" "$1"; }

echo "=========================================="
echo "  Postsible Mailserver - Setup"
echo "=========================================="
echo ""

# ── Argument parsing ───────────────────────────────────────────────────────────
REMOTE_MODE=false
REMOTE_HOST=""
REMOTE_USER="root"
INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --remote)      REMOTE_MODE=true; REMOTE_HOST="$2"; shift 2 ;;
        --user)        REMOTE_USER="$2"; shift 2 ;;
        --interactive) INTERACTIVE=true; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --remote <host>    Deploy to remote server (IP or hostname)"
            echo "  --user <user>      SSH user for remote (default: root)"
            echo "  --interactive      Interactive mode (recommended)"
            echo "  --help             Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --interactive"
            echo "  $0 --remote 192.168.1.100 --interactive"
            exit 0 ;;
        *) print_error "Unknown option: $1"; echo "Use --help for usage."; exit 1 ;;
    esac
done

# ── OS detection ───────────────────────────────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release; OS=$ID; VERSION=$VERSION_ID
else
    print_error "Cannot detect OS"; exit 1
fi
print_success "Detected OS: $OS $VERSION"

# ── Root check (local mode only) ──────────────────────────────────────────────
if [ "$REMOTE_MODE" = false ] && [ "$EUID" -ne 0 ]; then
    print_error "Local setup must be run as root."; exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# Domain collection
# ══════════════════════════════════════════════════════════════════════════════

# Arrays for domain data
DOMAIN_LIST=()
MX_HOSTNAME_LIST=()
ADMIN_EMAIL_LIST=()

collect_domain() {
    local idx=$1
    local label=$2
    local domain mx_hostname admin_email

    echo ""
    printf "${BOLD}%s${NC}\n" "$label"
    printf '%0.s─' {1..40}; echo ""

    # Domain
    while true; do
        read -p "Domain name (e.g. example.com): " domain
        domain="${domain,,}"  # lowercase
        if [[ "$domain" =~ ^[a-z0-9]([a-z0-9\-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]*[a-z0-9])?)+$ ]]; then
            break
        fi
        print_warning "Invalid domain name. Try again."
    done

    # MX hostname
    local default_mx="mail.${domain}"
    read -p "MX hostname [${default_mx}]: " mx_hostname
    mx_hostname="${mx_hostname:-$default_mx}"
    mx_hostname="${mx_hostname,,}"

    # Admin email
    local default_admin="admin@${domain}"
    read -p "Admin email [${default_admin}]: " admin_email
    admin_email="${admin_email:-$default_admin}"

    DOMAIN_LIST+=("$domain")
    MX_HOSTNAME_LIST+=("$mx_hostname")
    ADMIN_EMAIL_LIST+=("$admin_email")

    print_success "Domain added: $domain  (MX: $mx_hostname, Admin: $admin_email)"
}

# ── Remote host ───────────────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ] && [ -z "$REMOTE_HOST" ]; then
    echo ""
    read -p "Deploy to remote server? (y/n) [n]: " deploy_remote
    if [[ "$deploy_remote" =~ ^[Yy]$ ]]; then
        REMOTE_MODE=true
        read -p "Enter server IP or hostname: " REMOTE_HOST
        read -p "SSH user [${REMOTE_USER}]: " input_user
        REMOTE_USER="${input_user:-$REMOTE_USER}"
    fi
fi

# ── Collect primary domain ────────────────────────────────────────────────────
print_header "Domain Configuration"

echo "Every domain needs:"
echo "  • A DNS A record:  <mx_hostname>  →  <server IP>"
echo "  • A DNS MX record: <domain>       →  <mx_hostname>"
echo "  • Optional:        autoconfig.<domain>    →  <server IP>"
echo "  • Optional:        autodiscover.<domain>  →  <server IP>"
echo ""
print_info "DNS records can be added later. Self-signed certs will be used until then."
echo ""

collect_domain 0 "Primary Domain"
PRIMARY_DOMAIN="${DOMAIN_LIST[0]}"

# ── Additional domains ────────────────────────────────────────────────────────
echo ""
while true; do
    read -p "Add another domain? (y/n) [n]: " add_more
    if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
        break
    fi
    collect_domain ${#DOMAIN_LIST[@]} "Additional Domain $((${#DOMAIN_LIST[@]}))"
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
print_header "Configuration Summary"

[ "$REMOTE_MODE" = true ] && print_info "Deployment: Remote ($REMOTE_USER@$REMOTE_HOST)" \
                           || print_info "Deployment: Local"
echo ""
echo "Domains configured: ${#DOMAIN_LIST[@]}"
for i in "${!DOMAIN_LIST[@]}"; do
    local_label=""
    [ $i -eq 0 ] && local_label=" (primary)"
    printf "  %d. %-25s  MX: %-30s  Admin: %s%s\n" \
        $((i+1)) "${DOMAIN_LIST[$i]}" "${MX_HOSTNAME_LIST[$i]}" "${ADMIN_EMAIL_LIST[$i]}" "$local_label"
done

echo ""
read -p "Continue with this configuration? (y/n) [y]: " confirm
[[ "$confirm" =~ ^[Nn]$ ]] && echo "Setup cancelled." && exit 0

# ══════════════════════════════════════════════════════════════════════════════
# Ansible installation
# ══════════════════════════════════════════════════════════════════════════════
print_header "Installing Ansible"

if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        apt update -qq
        apt install -y ansible git python3-pip sshpass
    else
        print_error "Unsupported OS. Debian/Ubuntu required."; exit 1
    fi
    print_success "Ansible installed: $(ansible --version | head -n1)"
else
    print_success "Ansible already installed: $(ansible --version | head -n1)"
fi

echo ""
echo "Installing Ansible collections..."
ansible-galaxy collection install community.general  2>/dev/null || true
ansible-galaxy collection install community.mysql    2>/dev/null || true
ansible-galaxy collection install ansible.posix      2>/dev/null || true
print_success "Collections installed"

# ══════════════════════════════════════════════════════════════════════════════
# SSH setup
# ══════════════════════════════════════════════════════════════════════════════
print_header "SSH Configuration"

if [ "$REMOTE_MODE" = true ]; then
    # Generate key if needed
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "ansible@postsible"
        print_success "SSH key generated"
    fi

    # Test connection
    echo "Testing SSH to $REMOTE_USER@$REMOTE_HOST ..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
           "$REMOTE_USER@$REMOTE_HOST" "echo OK" &>/dev/null; then
        print_success "SSH key-based auth works"
    else
        print_warning "Key-based auth not set up. Copying SSH key..."
        if command -v ssh-copy-id &>/dev/null; then
            ssh-copy-id -i ~/.ssh/id_ed25519.pub "$REMOTE_USER@$REMOTE_HOST"
        else
            print_warning "ssh-copy-id not found. Add this key manually:"
            cat ~/.ssh/id_ed25519.pub
            read -p "Press Enter after adding the key..."
        fi
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
               "$REMOTE_USER@$REMOTE_HOST" "echo OK" &>/dev/null; then
            print_success "SSH key configured successfully"
        else
            print_warning "SSH still requires password. Use --ask-pass with ansible-playbook."
        fi
    fi
else
    # Local: ensure key + authorized_keys
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "ansible@postsible"
        cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        print_success "SSH key generated and added to authorized_keys"
    fi

    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@localhost \
           "echo OK" &>/dev/null; then
        print_success "SSH localhost works"
    else
        print_warning "SSH to localhost failed. Check sshd and authorized_keys."
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# Write inventory/hosts.yml
# ══════════════════════════════════════════════════════════════════════════════
print_header "Writing Inventory"

mkdir -p inventory/group_vars/mailservers

PRIMARY_MX="${MX_HOSTNAME_LIST[0]}"

if [ "$REMOTE_MODE" = true ]; then
    cat > inventory/hosts.yml << EOF
---
# Postsible Inventory – generated by setup.sh on $(date)

mailservers:
  hosts:
    ${PRIMARY_MX}:
      ansible_host: ${REMOTE_HOST}
      ansible_user: ${REMOTE_USER}
      ansible_python_interpreter: /usr/bin/python3
      common_hostname: ${PRIMARY_MX}
      # ansible_ssh_pass: "{{ vault_ansible_ssh_pass }}"
      # ansible_become_pass: "{{ vault_ansible_become_pass }}"
EOF
else
    REMOTE_HOST="localhost"
    cat > inventory/hosts.yml << EOF
---
# Postsible Inventory – generated by setup.sh on $(date)

mailservers:
  hosts:
    ${PRIMARY_MX}:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
      common_hostname: ${PRIMARY_MX}
EOF
fi
print_success "inventory/hosts.yml written"

# ══════════════════════════════════════════════════════════════════════════════
# Write inventory/group_vars/mailservers/vars.yml
# ══════════════════════════════════════════════════════════════════════════════

# Build YAML list for mail_virtual_domains
DOMAINS_YAML=""
for i in "${!DOMAIN_LIST[@]}"; do
    DOMAINS_YAML="${DOMAINS_YAML}  - domain: ${DOMAIN_LIST[$i]}
    mx_hostname: ${MX_HOSTNAME_LIST[$i]}
    admin_email: ${ADMIN_EMAIL_LIST[$i]}
"
done

cat > inventory/group_vars/mailservers/vars.yml << EOF
---
# Postsible Mailserver Configuration (Public)
# Sensitive data → vault.yml  (ansible-vault encrypt vault.yml)
# Generated by setup.sh on $(date)

# ── Common ────────────────────────────────────────────────────────────────────
common_timezone: "Europe/Vienna"
common_locales:
  - de_AT.UTF-8
  - en_US.UTF-8
common_default_locale: "de_AT.UTF-8"

# ── Primary domain ────────────────────────────────────────────────────────────
mail_primary_domain: "${PRIMARY_DOMAIN}"

# ── Virtual domains ───────────────────────────────────────────────────────────
# mx_hostname : A record pointing to this server
# admin_email : notifications for this domain
#
mail_virtual_domains:
${DOMAINS_YAML}
# ── Let's Encrypt ─────────────────────────────────────────────────────────────
mail_letsencrypt_email: "${ADMIN_EMAIL_LIST[0]}"
certbot_skip: false
certbot_dns_check: true

# ── SSL paths ─────────────────────────────────────────────────────────────────
mail_ssl_cert_path: "/etc/letsencrypt/live"

# ── Ports ─────────────────────────────────────────────────────────────────────
mail_imap_port: 993
mail_smtp_port: 465

# ── MariaDB ───────────────────────────────────────────────────────────────────
mariadb_database: "mailserver"
mariadb_user: "mailuser"
mariadb_host: "127.0.0.1"
mariadb_root_password: "{{ vault_mariadb_root_password }}"
mariadb_password: "{{ vault_mariadb_password }}"

# ── Postfix ───────────────────────────────────────────────────────────────────
postfix_myhostname: "{{ mail_virtual_domains[0].mx_hostname }}"
postfix_mydomain:   "{{ mail_primary_domain }}"
postfix_myorigin:   "\$mydomain"
postfix_inet_interfaces: "all"
postfix_inet_protocols:  "all"
postfix_recipient_delimiter: "+"

# ── Dovecot ───────────────────────────────────────────────────────────────────
dovecot_mail_location: "maildir:/srv/imap/%d/%n/"
dovecot_protocols: "imap lmtp sieve"

# ── Rspamd ────────────────────────────────────────────────────────────────────
rspamd_webui_enabled: true
rspamd_webui_password: "{{ vault_rspamd_webui_password }}"

# ── SnappyMail ────────────────────────────────────────────────────────────────
snappymail_domain: "{{ mail_virtual_domains[0].mx_hostname }}"
snappymail_admin_user: "admin"
snappymail_admin_password: "{{ vault_snappymail_admin_password }}"

# ── InfCloud ──────────────────────────────────────────────────────────────────
infcloud_use_subdomain: false
infcloud_base_path: "/cal"
infcloud_language: "de_DE"
infcloud_timezone: "Europe/Vienna"
infcloud_first_day_of_week: 1
infcloud_enable_calendar: true
infcloud_enable_contacts: true
infcloud_enable_projects: false
infcloud_title: "My Company Calendar"
infcloud_logo_text: "{{ mail_primary_domain }}"

# ── Nginx ─────────────────────────────────────────────────────────────────────
nginx_worker_processes: "auto"
nginx_worker_connections: 1024

# ── UFW ───────────────────────────────────────────────────────────────────────
ufw_ssh_port: 22
ufw_ssh_trusted_ips: []
ufw_enable_smtps: true
ufw_enable_pop3s: false
ufw_rate_limit_smtp: false
ufw_logging_level: "low"

# ── Fail2ban ──────────────────────────────────────────────────────────────────
fail2ban_bantime: 3600
fail2ban_findtime: 600
fail2ban_maxretry: 5
fail2ban_destemail: "{{ mail_virtual_domains[0].admin_email }}"

# ── ESET ICAP (optional) ──────────────────────────────────────────────────────
eset_icap_enabled: false
eset_icap_host: "localhost"
eset_icap_port: 1344
EOF

print_success "inventory/group_vars/mailservers/vars.yml written"

# ══════════════════════════════════════════════════════════════════════════════
# Write vault.yml.example
# ══════════════════════════════════════════════════════════════════════════════

if [ ! -f "inventory/group_vars/mailservers/vault.yml" ]; then
    cat > inventory/group_vars/mailservers/vault.yml.example << EOF
---
# Postsible Vault – copy to vault.yml, fill in passwords, then:
#   ansible-vault encrypt inventory/group_vars/mailservers/vault.yml

vault_mariadb_root_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"
vault_mariadb_password:      "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"
vault_rspamd_webui_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"
vault_snappymail_admin_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"
vault_baikal_admin_password: "CHANGE_ME_$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)"
# vault_ansible_ssh_pass: "YOUR_SSH_PASSWORD"
# vault_ansible_become_pass: "YOUR_SUDO_PASSWORD"
EOF
    print_success "vault.yml.example written"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Summary & next steps
# ══════════════════════════════════════════════════════════════════════════════
print_header "Setup Complete!"

print_success "Configuration written for ${#DOMAIN_LIST[@]} domain(s)"
echo ""
echo "Domains:"
for i in "${!DOMAIN_LIST[@]}"; do
    printf "  • %-25s  MX: %s\n" "${DOMAIN_LIST[$i]}" "${MX_HOSTNAME_LIST[$i]}"
done

echo ""
printf "${BOLD}${YELLOW}Required DNS records:${NC}\n\n"
for i in "${!DOMAIN_LIST[@]}"; do
    printf "  # %s\n" "${DOMAIN_LIST[$i]}"
    printf "  %-35s IN  A    <server-ip>\n"   "${MX_HOSTNAME_LIST[$i]}"
    printf "  %-35s IN  MX   10 %s\n"         "${DOMAIN_LIST[$i]}."   "${MX_HOSTNAME_LIST[$i]}"
    printf "  %-35s IN  A    <server-ip>   # optional: autoconfig\n"  "autoconfig.${DOMAIN_LIST[$i]}"
    printf "  %-35s IN  A    <server-ip>   # optional: autodiscover\n" "autodiscover.${DOMAIN_LIST[$i]}"
    printf "  %-35s IN  TXT  \"v=spf1 mx -all\"\n" "${DOMAIN_LIST[$i]}."
    echo ""
done

printf "${BOLD}Next steps:${NC}\n\n"
printf "1. Set passwords in vault:\n"
printf "   cp inventory/group_vars/mailservers/vault.yml.example \\ \n"
printf "      inventory/group_vars/mailservers/vault.yml\n"
printf "   \$EDITOR inventory/group_vars/mailservers/vault.yml\n"
printf "   ansible-vault encrypt inventory/group_vars/mailservers/vault.yml\n\n"

printf "2. Test connection:\n"
printf "   ansible mailservers -m ping --ask-vault-pass\n\n"

printf "3. Deploy:\n"
printf "   ansible-playbook playbooks/site.yml --ask-vault-pass\n\n"

printf "4. After deploy – add DKIM records:\n"
printf "   cat /root/dkim-dns-records.txt  (on the server)\n\n"

printf "5. Re-run certbot after DNS is set:\n"
printf "   ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass\n\n"

printf "${BLUE}==========================================${NC}\n"
