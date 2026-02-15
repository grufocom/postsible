# Postsible - Ansible Mail Server

A complete Ansible playbook for automated installation of a production-ready mail server on Debian 13.

### Foreword

Postsible was born out of frustration — and conviction.

Over time, I found myself increasingly dissatisfied with existing mail server solutions. Many of them come with significant overhead, unnecessary complexity, or architectural decisions that did not align with my expectations of a clean and maintainable system. At the same time, I was unable to find an actively maintained open-source project that offered exactly what I expect from a modern mail server: clarity, robustness, security, and operational simplicity without excessive abstraction layers.

In parallel, the ongoing geopolitical developments and the accelerating integration of AI into cloud-based mail platforms prompted me to rethink my reliance on hosted services. Email remains one of the most critical communication tools for businesses. For me, this raised an important question: Should such an essential infrastructure component be increasingly centralized, opaque, and externally controlled — or should it be operated independently, transparently, and with full ownership?

Postsible is my answer to that question.

The goal of this project is to provide a clean, modern, and securely hardened mail platform tailored for small to medium-sized businesses. It focuses on covering the essential features required in professional environments while avoiding unnecessary complexity.

This project is intended for those who want a properly secured, classic Linux mail server — without mandatory Docker stacks, without hidden layers, and without cloud dependency. It is for administrators who value transparency, control, and long-term maintainability.

Postsible aims to make self-hosting email practical again — straightforward, reliable, and future-proof.

---

## 📧 Features

- **📬 Postfix** - SMTP server with virtual domains
- **📭 Dovecot** - IMAP/POP3 with Sieve support
- **📭 Subaddressing / + Addressing** for flexible aliases in main mailbox
- **🛡️ Rspamd** - Spam filter with Bayes learning
- **🔐 DKIM/DMARC/SPF** - Email authentication (CRITICAL!)
- **🌐 SnappyMail** - Modern webmail interface
- **📅 Baikal** - CalDAV/CardDAV server for calendars & contacts
- **🌐 InfCloud** - Web-based CalDAV/CardDAV client (no native app needed)
- **🔒 Let's Encrypt** - Automatic SSL certificates
- **🔥 UFW** - Firewall configuration
- **🚫 Fail2ban** - Brute-force protection (6 jails incl. SnappyMail)
- **💾 MariaDB** - Virtual users & domains
- **🦠 ESET ICAP** - Antivirus scanner (optional)
- **🔐 Security Hardening** - Defense-in-depth approach
- **⚙️ Autoconfig / Autodiscover Role**

---

## 🚀 Quick Start

### 1. Interactive Setup (recommended)

```bash
# Clone repository
git clone https://github.com/grufocom/postsible.git
cd postsible

# Start interactive setup
./setup.sh --interactive
```

The script asks for all important information:
- Remote or local deployment?
- Server IP address
- Domain (e.g., `example.com`)
- Mail server hostname (e.g., `mail.example.com`)
- Admin email address

### 2. Quick Setup with Parameters

```bash
# Remote deployment
./setup.sh --remote 192.168.1.100 \
           --domain example.com \
           --hostname mail.example.com \
           --admin-email admin@example.com

# Local deployment
./setup.sh --domain example.com \
           --hostname mail.example.com
```

### 3. Create and Encrypt Vault File

```bash
# Copy template
cp inventory/group_vars/mailservers/vault.yml.example \
   inventory/group_vars/mailservers/vault.yml

# Edit passwords in vault.yml (replace all CHANGE_ME)
nano inventory/group_vars/mailservers/vault.yml

# Encrypt vault
ansible-vault encrypt --ask-vault-password inventory/group_vars/mailservers/vault.yml
```

### 4. Configure DNS Records

**Before deployment** the following DNS records must be set:

```dns
# MX Record
example.com.           IN MX   10 mail.example.com.

# A Record (Server IP) - don't forget IPV6 if you want to use it!
mail.example.com.      IN A    192.168.1.100
autoconfig.example.com. IN CNAME mail.example.com
autodiscover.example.com. IN CNAME mail.example.com

# PTR Record (Reverse DNS - at your hosting provider)
100.1.168.192.in-addr.arpa. IN PTR mail.example.com.

# SPF Records
example.com.           IN TXT  "v=spf1 mx -all"
mail.example.com.      IN TXT  "v=spf1 a -all"
```

**After deployment** (DKIM keys are generated):

```dns
# DKIM Record (key from /root/dkim-dns-records.txt on server)
dkim._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=MIIBIj..."

# DMARC Record
_dmarc.example.com.    IN TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; adkim=s; aspf=s"
```

### 5. Start Deployment

```bash
# Complete deployment
ansible-playbook playbooks/site.yml --ask-vault-pass

# Or phase by phase
ansible-playbook playbooks/site.yml --tags phase1 --ask-vault-pass
ansible-playbook playbooks/site.yml --tags phase2 --ask-vault-pass
# etc.
```

### 6. Admin User Credentials

After deployment, the admin user is automatically created with a secure password:
```bash
# View admin credentials
cat /root/admin-credentials.txt

# IMPORTANT: Save the password securely, then delete the file!
rm /root/admin-credentials.txt
```

The admin user email is: `admin@example.com` (or whatever you configured as `mail_admin_email`)
---

## 📋 System Requirements

- **OS:** Debian 13 (Trixie) - fresh installation
- **RAM:** At least 2 GB
- **Disk:** 20 GB disk space
- **Access:** Root access via SSH
- **Network:** Public IPv4 address
- **DNS:** Configured DNS records (see above)

---

## 🏗️ Deployment Phases

### Phase 1: Base Infrastructure
```bash
ansible-playbook playbooks/site.yml --tags phase1 --ask-vault-pass
```
- **common** - System updates & base packages
- **ufw** - Firewall configuration
- **mariadb** - Database for virtual users/domains

### Phase 2: Mail Core
```bash
ansible-playbook playbooks/site.yml --tags phase2 --ask-vault-pass
```
- **postfix** - SMTP server with intelligent SSL detection
- **dovecot** - IMAP/POP3 with Sieve support

### Phase 3: Spam Filter
```bash
ansible-playbook playbooks/site.yml --tags phase3 --ask-vault-pass
```
- **rspamd** - Spam filter, DKIM signing, Bayes learning
- **eset_icap** - Antivirus scanner (optional)

### Phase 4: Web & SSL
```bash
ansible-playbook playbooks/site.yml --tags phase4 --ask-vault-pass
```
- **nginx** - Web server with intelligent SSL detection
- **certbot** - Let's Encrypt SSL certificates
- **snappymail** - Webmail interface
- **baikal** - CalDAV/CardDAV server
- **infcloud** - Web CalDAV/CardDAV client

### Phase 5: Security
```bash
ansible-playbook playbooks/site.yml --tags phase5 --ask-vault-pass
```
- **fail2ban** - Brute-force protection (6 jails)

---

## 🎯 Run Individual Roles

```bash
# Update only Postfix
ansible-playbook playbooks/site.yml --tags postfix --ask-vault-pass

# Renew only SSL certificates
ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass

# Reconfigure only rspamd
ansible-playbook playbooks/site.yml --tags rspamd-configure --ask-vault-pass

# Update only Baikal
ansible-playbook playbooks/site.yml --tags baikal --ask-vault-pass
```

---

## 🔐 Security Features

### Intelligent SSL Detection
Postfix and Nginx automatically detect Let's Encrypt certificates:
1. Preferred: `/etc/letsencrypt/live/mail.example.com/`
2. Fallback: `/etc/letsencrypt/live/example.com/`
3. Fallback: Snakeoil (testing only)

### Fail2ban Jails
- **SSH** - Protection against brute-force on port 22
- **Postfix SASL** - Auth failures during mail sending
- **Dovecot** - IMAP/POP3 login failures
- **Nginx HTTP Auth** - Web server authentication
- **SnappyMail** - Webmail login failures
- **Rspamd** - WebUI protection (optional)

### DKIM/SPF/DMARC
- Automatic DKIM key generation (2048-bit)
- ARC signing enabled
- Strict DMARC policy (configurable)

---

## 🔑 Admin User Setup

### Automatic Creation

During deployment, Postsible automatically creates an admin user with:
- **Email:** Your configured `mail_admin_email` (default: `admin@yourdomain.com`)
- **Password:** Auto-generated secure 20-character password
- **Credentials saved to:** `/root/admin-credentials.txt`

**After first login:**
1. Save the password to your password manager
2. Delete the credentials file: `rm /root/admin-credentials.txt`
3. Optionally change the password: `maildb-manage change-password admin@example.com`

### First Login

**Webmail (SnappyMail):**
- URL: `https://mail.example.com/wm/`
- Username: Full email address (e.g., `admin@example.com`)
- Password: From `/root/admin-credentials.txt`

**InfCloud (Calendar/Contacts):**
- URL: `https://mail.example.com/cal/`
- Username: Full email address
- Password: Same as webmail

**Baikal (Calendar/Contacts management):**
- URL: `https://mail.example.com/dav/admin/`
- Username: admin
- Password: From ansible vault

**Email Client (Thunderbird, Outlook, etc.):**
- IMAP: `mail.example.com:993` (SSL/TLS)
- SMTP: `mail.example.com:587` (STARTTLS)
- Username: Full email address
- Password: Same as webmail

---

## 🛠️ Manage Virtual Domains & Users

### Using maildb-manage (recommended)

The `maildb-manage` script simplifies management and automatically synchronizes with Baikal:

```bash
# Add domain
maildb-manage add-domain example.com

# List domains
maildb-manage list-domains

# Add user (also creates Baikal account with calendar & addressbook)
maildb-manage add-user user@example.com

# List users (shows Baikal status too)
maildb-manage list-users
maildb-manage list-users example.com

# Change password (synchronizes mail & Baikal)
maildb-manage change-password user@example.com

# Remove user (also removes Baikal data)
maildb-manage remove-user user@example.com

# Add alias
maildb-manage add-alias alias@example.com user@example.com

# Show statistics
maildb-manage stats

# Check database integrity (incl. mail/Baikal sync)
maildb-manage check

# Help
maildb-manage help
```

### Manual via SQL (for advanced users)

#### Add domain
```sql
mysql -u root -p mailserver
INSERT INTO virtual_domains (name) VALUES ('newdomain.com');
```

#### Add user
```bash
# Hash password
doveadm pw -s SHA512-CRYPT

# Insert user into database
mysql -u root -p mailserver
INSERT INTO virtual_users (domain_id, email, password)
VALUES (
  (SELECT id FROM virtual_domains WHERE name='example.com'),
  'user@example.com',
  '{SHA512-CRYPT}YOUR_HASHED_PASSWORD'
);
```

#### Add alias
```sql
INSERT INTO virtual_aliases (domain_id, source, destination)
VALUES (
  (SELECT id FROM virtual_domains WHERE name='example.com'),
  'alias@example.com',
  'user@example.com'
);
```

---

## 🌐 Access Credentials

After successful deployment:

### Webmail
- **URL:** `https://mail.example.com/wm/`
- **Login:** Complete email address + password

### InfCloud (Web Calendar/Contacts)
- **URL:** https://cloud.example.com or https://mail.example.com/cloud/
- **Login:** Complete email address + password
- **Features:** Calendar (CalDAV), Contacts (CardDAV), Tasks - browser-based, no app installation needed

### Baikal (CalDAV/CardDAV)
- **URL:** `https://dav.example.com` or `https://mail.example.com/dav/`
- **Login:** Complete email address + password
- **CalDAV:** `https://dav.example.com/dav.php/calendars/user@example.com/`
- **CardDAV:** `https://dav.example.com/dav.php/addressbooks/user@example.com/`

**Important:** Baikal accounts are created automatically when users are added via `maildb-manage add-user`. Each user receives:
- Default calendar "Personal"
- Default addressbook "Contacts"

### Rspamd WebUI
- **URL:** `https://mail.example.com/rspamd/`
- **Password:** From `vault_rspamd_webui_password`

### IMAP Access
- **Server:** mail.example.com
- **Port:** 993 (SSL/TLS)
- **Auth:** Email address + password

### SMTP Sending
- **Server:** mail.example.com
- **Port:** 587 (STARTTLS) or 465 (SSL/TLS)
- **Auth:** Email address + password

---

## 📅 Calendar & Contacts (InfCloud + Baikal)

🎉 InfCloud - Web Client (Primary Access)
https://cloud.example.com
Login: user@example.com + password

✅ Calendars & Events
✅ Contacts management  
✅ Tasks/Todos
✅ Mobile-friendly
✅ Multi-user ready
✅ Automatic user provisioning via maildb-manage

🔧 Baikal - Server Backend (Mobile/Desktop Sync)

For native apps (iOS, Android, Thunderbird, Outlook)

### Client Configuration

#### iOS/macOS
1. **Settings → Accounts → Add Account**
2. **Other → CalDAV/CardDAV Account**
3. **Server:** `dav.example.com` (or `mail.example.com/dav`)
4. **Username:** Complete email address
5. **Password:** Your mail password

#### Thunderbird
1. **Install add-on:** TbSync + Provider for CalDAV & CardDAV
2. **Add account → CalDAV & CardDAV**
3. **Server:** `https://dav.example.com/dav.php/`
4. **Username:** Email address

#### Android
- **DAVx⁵** from F-Droid/Play Store
- **Base URL:** `https://dav.example.com/dav.php/`
- **Login:** Email address + password

### 🔄 Automatic Synchronization

When users are created via `maildb-manage add-user`:
- ✅ Baikal account is created automatically
- ✅ Default calendar "Personal" is created
- ✅ Default addressbook "Contacts" is created
- ✅ Passwords are synchronized between mail & Baikal
- ✅ All Baikal data is removed when deleting users

### 📦 Import Existing Data
**Import Calendars (.ics)**
Recommended: Thunderbird + Lightning → Import → Syncs to Baikal

**Import Contacts (.vcf)**
Recommended: Thunderbird + CardBook → Import → Syncs to Baikal

No manual database imports needed - data syncs automatically to server.

---

## 🔧 Maintenance

### Check Logs
```bash
# Mail logs
tail -f /var/log/mail/mail.log

# Rspamd logs
tail -f /var/log/rspamd/rspamd.log

# Nginx logs
tail -f /var/log/nginx/access.log

# Baikal logs (via Nginx)
tail -f /var/log/nginx/rspamd-access.log
tail -f /var/log/nginx/rspamd-error.log
```

### Service Status
```bash
# Postfix
systemctl status postfix
postfix check

# Dovecot
systemctl status dovecot
doveadm user '*'

# Rspamd
systemctl status rspamd
rspamc stat
/usr/local/bin/rspamd-stats.sh

# Baikal (via PHP-FPM)
systemctl status php8.2-fpm
systemctl status nginx

# Fail2ban
fail2ban-client status
fail2ban-client status postfix-sasl
```

### Spam Learning
Users can train themselves:
1. Move spam mails to `.Spam/` folder
2. Move false positives to `.Ham/` folder
3. Rspamd learns automatically via cronjob (every 30min + daily at 3:00 AM)

### Renew SSL Certificates
```bash
# Runs automatically via Certbot
# Manually:
certbot renew
systemctl reload postfix dovecot nginx
```

### Check Baikal Database
```bash
# Check sync between mail and Baikal
maildb-manage check

# List Baikal users manually
mysql -u root -p mailserver -e "SELECT * FROM users;"

# Check calendars of a user
mysql -u root -p mailserver -e "
  SELECT ci.displayname, ci.uri, c.components 
  FROM calendarinstances ci 
  JOIN calendars c ON ci.calendarid = c.id 
  WHERE ci.principaluri = 'principals/user@example.com';
"
```

### Subaddressing / + Addressing (Catch-All Suffix)
Postsible now supports subaddressing using the + symbol. This allows users to add arbitrary suffixes to their email addresses without creating new mailboxes.

**Example:**
Primary address: hans.meiser@domain.com
Subaddress: hans.meiser+newsletter@domain.com

All emails will automatically be delivered to the hans.meiser mailbox.

**Use Cases:**
Filter emails by project, newsletter, or source
Track where emails originate from

No extra database entries or mailbox management required

**Technical Details:**
Postfix: main.cf contains
recipient_delimiter = +

Dovecot: 10-mail.conf contains
mailbox_delimiter = +

**SQL Maps:** virtual-mailbox-maps, virtual-alias-maps, email2email handle the stripping of the + suffix
Dovecot SQL Queries: %{u}@%{d} ensures correct user resolution

Admin Examples:
```bash
# Test email locally with Postfix
echo "Test mail" | sendmail hans.meiser+1234@domain.com
# Fetch mail via Dovecot
doveadm fetch text subject hans.meiser+abc@domain.com
```

Sieve Filtering Example:

```bash
require ["fileinto"];
if address :contains "to" "+newsletter" {
    fileinto "Newsletter";
}
```

### Autoconfig / Autodiscover Role
- Automatic Thunderbird autoconfig (Mozilla standard)
- Automatic Outlook / ActiveSync autodiscover (Microsoft standard)
- DNS validation for autoconfig.domain.tld
- Nginx configuration with HTTP → HTTPS upgrade
- Fully idempotent, works for all virtual domains
- Automatic Let's Encrypt certificate provisioning via Certbot

**Deployment / Nginx Integration Notes**

- Each virtual domain gets its own autoconfig subdirectory:

```bash
/var/www/autoconfig/<domain>/mail/config-v1.1.xml
```

- Thunderbird / Lightning expects the XML at:

```bash
https://autoconfig.example.com/mail/config-v1.1.xml
```

- Certbot automatically requests certificates for the autoconfig subdomain.
- Nginx handles both HTTP → HTTPS redirection and serving of autoconfig files.

**Example structure for multiple domains:**

/var/www/autoconfig/
├── example.com/
│   └── mail/config-v1.1.xml
├── example.net/
│   └── mail/config-v1.1.xml


Fully automated via the Ansible autoconfig role:
- Generates XML files per domain
- Ensures Nginx configuration is correct
- Requests and renews SSL certificates

---

## 🐛 Troubleshooting

### DKIM Not Working
```bash
# Check DKIM keys
ls -la /var/lib/rspamd/dkim/

# Restart rspamd
systemctl restart rspamd

# Watch log
tail -f /var/log/rspamd/rspamd.log | grep -i dkim

# Send test mail and check
# Should show: DKIM_SIGNED(0.00){example.com:s=dkim;}
```

### Mail Marked as Spam
```bash
# Run checks
# 1. SPF check
dig TXT example.com +short
dig TXT mail.example.com +short

# 2. DKIM check
dig TXT dkim._domainkey.example.com +short

# 3. DMARC check
dig TXT _dmarc.example.com +short

# 4. Reverse DNS (PTR)
dig -x YOUR_SERVER_IP +short

# Online tests
# https://www.mail-tester.com/
# https://mxtoolbox.com/SuperTool.aspx
```

### Baikal Not Working
```bash
# Check PHP-FPM status
systemctl status php8.2-fpm

# Test Nginx config
nginx -t

# Check Baikal permissions
ls -la /var/www/baikal/
# Should be: www-data:www-data

# Test database connection
mysql -u root -p mailserver -e "SELECT COUNT(*) FROM users;"

# Create Baikal user manually (if maildb-manage doesn't work)
mysql -u root -p mailserver
INSERT INTO users (username, digesta1) VALUES ('test@example.com', 'hash');

# Clear browser cache and try again
# Check CalDAV/CardDAV discovery URLs:
curl -I https://dav.example.com/.well-known/caldav
curl -I https://dav.example.com/.well-known/carddav
```

### Firewall Issues
```bash
# Check status
ufw status verbose

# Open port (if needed)
ufw allow 587/tcp comment "SMTP Submission"
```

---

## 📁 Project Structure

```
postsible/
├── inventory/
│   ├── hosts.yml                           # Server inventory
│   └── group_vars/
│       └── mailservers/
│           ├── vars.yml                    # Public variables
│           └── vault.yml                   # Encrypted secrets
├── roles/
│   ├── common/                             # System base
│   ├── ufw/                                # Firewall
│   ├── mariadb/                            # Database (+ Baikal tables)
│   │   └── templates/
│   │       └── maildb-manage.sh.j2         # User management with Baikal sync
│   ├── postfix/                            # SMTP
│   ├── dovecot/                            # IMAP/Sieve
│   ├── rspamd/                             # Spam filter + DKIM
│   ├── nginx/                              # Web server
│   ├── certbot/                            # SSL
│   ├── snappymail/                         # Webmail
│   ├── baikal/                             # CalDAV/CardDAV server
│   ├── infcloud/                           # Web CalDAV/CardDAV client
│   ├── fail2ban/                           # Brute-force protection
│   └── eset_icap/                          # Antivirus (optional)
├── playbooks/
│   ├── site.yml                            # Main playbook
│   └── maintenance.yml                     # Maintenance playbook
├── setup.sh                                # Intelligent setup script
├── ansible.cfg                             # Ansible configuration
└── README.md                               # This file
```

---

## 🔄 Updates & Backups

### System Updates
```bash
ansible-playbook playbooks/maintenance.yml --tags update --ask-vault-pass
```

### Backup Important Data
```bash
# MariaDB (incl. Baikal data)
mysqldump -u root -p mailserver > mailserver-backup.sql

# Mailboxes
tar czf mailboxes-backup.tar.gz /srv/imap/

# Baikal data (if separate files exist)
tar czf baikal-backup.tar.gz /var/www/baikal/Specific/

# Configuration
tar czf config-backup.tar.gz /etc/postfix /etc/dovecot /etc/rspamd /etc/nginx
```

---

## 🤝 Known Issues & Solutions

### rspamd Neural Network Crashes
**Problem:** Neural network module causes segmentation faults
**Solution:** Neural network is disabled by default (`rspamd_enable_neural: false`)
**Bayes filter alone is sufficient for 95% of spam detection**

### sign_headers Causes DKIM Crash
**Problem:** Custom `sign_headers` list leads to rspamd crash
**Solution:** Removed from template, rspamd uses sensible defaults

### Baikal Calendars Not Deleted
**Problem:** Manual user deletion leaves Baikal data behind
**Solution:** Always use `maildb-manage remove-user` - the script automatically removes all Baikal data (calendars, calendarinstances, addressbooks, cards, principals)

---

## 📚 Further Documentation

- **Rspamd:** https://rspamd.com/doc/
- **Postfix:** http://www.postfix.org/documentation.html
- **Dovecot:** https://doc.dovecot.org/
- **SnappyMail:** https://snappymail.eu/
- **Baikal:** https://sabre.io/baikal/
- **fail2ban:** https://github.com/fail2ban/fail2ban/wiki

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file

---

## 🙏 Credits

Developed as a comprehensive mail server solution focusing on:
- **Security** (DKIM, SPF, DMARC, fail2ban, SSL)
- **User-friendliness** (Interactive setup, automatic config, CalDAV/CardDAV)
- **Maintainability** (Ansible, modular structure, good documentation)
- **Production-readiness** (Tested, stable, best practices)

---

## 💡 Support

For issues:
1. Check logs (`/var/log/mail/`, `/var/log/rspamd/`, `/var/log/nginx/`)
2. Check service status (`systemctl status postfix dovecot rspamd php8.2-fpm`)
3. Create GitHub issues: https://github.com/grufocom/postsible/issues
4. Consult community forum

---
