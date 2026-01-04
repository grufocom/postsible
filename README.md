# Postsible – Ansible Mail Server

A complete Ansible playbook for the automated installation of a production-ready mail server on Debian 13.

## Features

* 📧 **Postfix** – SMTP server with virtual domains
* 📬 **Dovecot** – IMAP/POP3 with Sieve support
* 🛡️ **Rspamd** – Spam filter with Bayesian learning
* 🌐 **SnappyMail** – Modern webmail interface
* 🔒 **Let’s Encrypt** – Automatic SSL certificates
* 🔥 **UFW** – Firewall configuration
* 🚫 **Fail2ban** – Brute-force protection
* 💾 **MariaDB** – Virtual users & domains
* 🦠 **ESET ICAP** – Virus scanner (optional)

## System Requirements

* Debian 13 (Trixie) – fresh installation
* At least 2 GB RAM
* 20 GB disk space
* Root access via SSH
* Public IPv4 address
* Configured DNS records (A, MX, PTR)

## Quick Start

### 1. Project Setup

```bash
# Run setup script
bash setup.sh

# Change into project directory
cd postsible
```

### 2. Adjust Inventory

Edit `inventory/hosts.yml`:

```yaml
mailservers:
  hosts:
    mail.example.com:
      ansible_host: YOUR_SERVER_IP
      ansible_user: root
      common_hostname: mail.example.com
```

### 3. Configure Variables

Edit `inventory/group_vars/mailservers.yml`:

```yaml
mail_primary_domain: "example.com"
mail_admin_email: "admin@example.com"
mariadb_root_password: "SECURE_PASSWORD"
mariadb_password: "SECURE_PASSWORD"
rspamd_webui_password: "SECURE_PASSWORD"
snappymail_admin_password: "SECURE_PASSWORD"
```

### 4. Test SSH Access

```bash
ansible mailservers -m ping
```

### 5. Start Deployment

```bash
# Full installation
ansible-playbook playbooks/site.yml

# Or only specific phases
ansible-playbook playbooks/site.yml --tags phase1
ansible-playbook playbooks/site.yml --tags phase2
# etc.
```

## Deployment Phases

### Phase 1: Base Infrastructure

```bash
ansible-playbook playbooks/site.yml --tags phase1
```

* System updates & base packages
* Firewall (UFW)
* MariaDB database

### Phase 2: Mail Core

```bash
ansible-playbook playbooks/site.yml --tags phase2
```

* Postfix (SMTP)
* Dovecot (IMAP/Sieve)

### Phase 3: Spam & Antivirus

```bash
ansible-playbook playbooks/site.yml --tags phase3
```

* Rspamd (spam filter)
* ESET ICAP (optional)

### Phase 4: Web & SSL

```bash
ansible-playbook playbooks/site.yml --tags phase4
```

* Nginx (web server)
* Certbot (Let’s Encrypt)
* SnappyMail (webmail)

### Phase 5: Security

```bash
ansible-playbook playbooks/site.yml --tags phase5
```

* Fail2ban

## Running Individual Roles

```bash
# Update Postfix only
ansible-playbook playbooks/site.yml --tags postfix

# Renew SSL certificates only
ansible-playbook playbooks/site.yml --tags certbot
```

## DNS Configuration

After deployment, the following DNS records must be configured:

### MX Record

```
example.com.  IN  MX  10  mail.example.com.
```

### A Record

```
mail.example.com.  IN  A  YOUR_SERVER_IP
```

### PTR Record (Reverse DNS)

```
IP.REVERSE.IN-ADDR.ARPA.  IN  PTR  mail.example.com.
```

### SPF Record

```
example.com.  IN  TXT  "v=spf1 mx ~all"
```

### DKIM Record

Retrieve the DKIM key after deployment:

```bash
ssh root@mail.example.com "cat /var/lib/rspamd/dkim/example.com.txt"
```

Add it as a TXT record:

```
dkim._domainkey.example.com.  IN  TXT  "v=DKIM1; k=rsa; p=YOUR_PUBLIC_KEY"
```

### DMARC Record

```
_dmarc.example.com.  IN  TXT  "v=DMARC1; p=quarantine; rua=mailto:admin@example.com"
```

## Managing Virtual Domains & Users

### Add a Domain

```bash
mysql -u root -p mailserver
```

```sql
INSERT INTO virtual_domains (name) VALUES ('newdomain.com');
```

### Add a User

```sql
-- Hash password (on the server)
doveadm pw -s SHA512-CRYPT

-- Insert user into database
INSERT INTO virtual_users (domain_id, email, password)
VALUES (
  (SELECT id FROM virtual_domains WHERE name='example.com'),
  'user@example.com',
  '{SHA512-CRYPT}YOUR_HASHED_PASSWORD'
);
```

### Add an Alias

```sql
INSERT INTO virtual_aliases (domain_id, source, destination)
VALUES (
  (SELECT id FROM virtual_domains WHERE name='example.com'),
  'alias@example.com',
  'user@example.com'
);
```

## Access Details

After successful deployment:

### Webmail

* URL: `https://webmail.example.com`
* Login: Full email address

### Rspamd WebUI

* URL: `https://mail.example.com/rspamd`
* Password: See `rspamd_webui_password`

### IMAP Access

* Server: `mail.example.com`
* Port: `993` (SSL/TLS)
* Auth: Email address + password

### SMTP Sending

* Server: `mail.example.com`
* Port: `587` (STARTTLS)
* Auth: Email address + password

## Maintenance

### Maintenance Playbook

```bash
# System updates
ansible-playbook playbooks/maintenance.yml --tags update

# System check
ansible-playbook playbooks/maintenance.yml --tags check

# Database backup
ansible-playbook playbooks/maintenance.yml --tags backup

# Restart services
ansible-playbook playbooks/maintenance.yml --tags restart
```

### Log Files

```bash
# Mail logs
tail -f /var/log/mail/mail.log

# Rspamd logs
tail -f /var/log/rspamd/rspamd.log

# Nginx logs
tail -f /var/log/nginx/access.log
```

### Spam Learning

Users can train spam/ham themselves:

1. Move spam emails to the `.Spam/` folder
2. Move falsely flagged emails to `.Ham/`
3. Rspamd learns automatically via cron job

## Troubleshooting

### Check Postfix Status

```bash
systemctl status postfix
journalctl -u postfix -f
postfix check
```

### Check Dovecot Status

```bash
systemctl status dovecot
doveadm log find
doveadm user '*'
```

### Check Rspamd Status

```bash
systemctl status rspamd
rspamc stat
```

### Connection Tests

```bash
# SMTP test
telnet mail.example.com 587

# IMAP test
openssl s_client -connect mail.example.com:993
```

### Firewall Status

```bash
ufw status verbose
```

## Security

### Renew SSL Certificates

Runs automatically via Certbot. Manual renewal:

```bash
certbot renew
```

### Change Passwords

Update all passwords in `inventory/group_vars/mailservers.yml` and redeploy.

### Fail2ban Status

```bash
fail2ban-client status
fail2ban-client status postfix-sasl
```

## Backup Strategy

### Important Directories

* `/srv/imap/` – All mailboxes
* `/etc/postsible/` – Configuration files
* MariaDB database

### Backup Script

```bash
# Manual backup
ansible-playbook playbooks/maintenance.yml --tags backup
```

## Project Structure

```
postsible/
├── roles/           # Ansible roles
│   ├── common/      # Base system
│   ├── ufw/         # Firewall
│   ├── mariadb/     # Database
│   ├── postfix/     # SMTP
│   ├── dovecot/     # IMAP/Sieve
│   ├── rspamd/      # Spam filter
│   ├── nginx/       # Web server
│   ├── certbot/     # SSL
│   ├── snappymail/  # Webmail
│   ├── fail2ban/    # Intrusion prevention
│   └── eset_icap/   # Antivirus
├── inventory/       # Server inventory
├── playbooks/       # Playbooks
└── ansible.cfg      # Ansible config
```

## License

MIT License

## Support

If you have questions or issues:

1. Check the logs
2. Open a GitHub issue
3. Consult the community forum

## Credits

Developed as a comprehensive mail server solution with a strong focus on security and usability.

---
