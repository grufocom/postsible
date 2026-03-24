# Postsible - Ansible Mail Server

A complete Ansible playbook for automated installation of a production-ready mail server on Debian 13, with full multi-domain support.

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

- **📬 Postfix** - SMTP server with virtual multi-domain support
- **📭 Dovecot** - IMAP/POP3 with Sieve support
- **📭 Subaddressing / + Addressing** for flexible aliases in main mailbox
- **🛡️ Rspamd** - Spam filter with Bayes learning
- **🔐 DKIM/DMARC/SPF** - Email authentication per domain (CRITICAL!)
- **🌐 SnappyMail** - Modern webmail interface, available on every domain
- **📅 Baikal** - CalDAV/CardDAV server for calendars & contacts
- **🌐 InfCloud** - Web-based CalDAV/CardDAV client (no native app needed)
- **✈️ Vacation Manager** - Out-of-office auto-replies with web interface & CLI
- **✍️ Signature Manager** - Per-user HTML email signatures with logo support
- **🔒 Let's Encrypt** - Automatic SSL certificates per domain (self-signed fallback)
- **🔥 UFW** - Firewall configuration
- **🚫 Fail2ban** - Brute-force protection (6 jails incl. SnappyMail)
- **💾 MariaDB** - Virtual users & domains
- **🦠 ESET ICAP** - Antivirus scanner (optional)
- **🔐 Security Hardening** - Defense-in-depth approach
- **⚙️ Autoconfig / Autodiscover** - Per-domain mail client autoconfiguration

---

## 🌐 Multi-Domain Architecture

Postsible is built from the ground up for multi-domain operation. Every domain is a first-class citizen — there is no "primary" domain that gets special treatment at the nginx level.

### How it works

Each domain in `mail_virtual_domains` gets:

| Component | What is created |
|---|---|
| **nginx vhost** | `mail.<domain>.conf` with its own SSL cert |
| **SSL certificate** | Let's Encrypt (or self-signed fallback) per `mx_hostname` |
| **Webmail** | `https://mail.<domain>/wm/` |
| **Rspamd WebUI** | `https://mail.<domain>/rspamd/` |
| **Vacation Manager** | `https://mail.<domain>/vacation/` |
| **Signature Manager** | `https://mail.<domain>/signature/` |
| **Autoconfig** | `autoconfig.<domain>` with own cert |
| **Autodiscover** | `autodiscover.<domain>` with own cert |
| **DKIM keypair** | `/var/lib/rspamd/dkim/<domain>.dkim.key` |

### vars.yml domain structure

```yaml
mail_primary_domain: "example.com"

mail_virtual_domains:
  - domain: example.com
    mx_hostname: mail.example.com
    admin_email: admin@example.com
  - domain: myotherdomain.com
    mx_hostname: mail.myotherdomain.com
    admin_email: admin@myotherdomain.com
```

Each entry requires:
- `domain` – the mail domain (used for email addresses and autoconfig)
- `mx_hostname` – the A record pointing to this server (used for nginx, SSL, IMAP/SMTP hostnames)
- `admin_email` – receives system notifications and Let's Encrypt registration for this domain

### SSL certificate strategy

```
For every mx_hostname and autoconfig/autodiscover subdomain:

  DNS resolves to this server?
    YES → certbot obtains Let's Encrypt certificate
           marker: /var/lib/postsible/certs/<hostname>.ok
    NO  → self-signed certificate is generated as fallback
           marker: /var/lib/postsible/certs/<hostname>.pending
           services remain fully operational, clients show cert warning

Once DNS is corrected, simply re-run:
  ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass
```

All certificate paths are identical for Let's Encrypt and self-signed (`/etc/letsencrypt/live/<hostname>/`), so nginx configuration never needs to change when upgrading from self-signed to LE.

---

## 🚀 Quick Start

### 1. Interactive Setup (recommended)

```bash
# Start with a plain Debian 13 server
apt install -y git

# Clone repository
git clone https://github.com/grufocom/postsible.git
cd postsible

# Start interactive setup
./setup.sh --interactive
```

The script asks for all important information:
- Remote or local deployment?
- Server IP address
- Primary domain (e.g., `example.com`) with MX hostname and admin email
- Additional domains (as many as needed, each with its own MX hostname and admin email)

### 2. Quick Setup with Parameters

```bash
# Remote deployment (interactive domain collection)
./setup.sh --remote 192.168.1.100 --interactive

# Local deployment
./setup.sh --interactive
```

### 3. Create and Encrypt Vault File

```bash
cp inventory/group_vars/mailservers/vault.yml.example \
   inventory/group_vars/mailservers/vault.yml

# Edit passwords (replace all CHANGE_ME values)
nano inventory/group_vars/mailservers/vault.yml

ansible-vault encrypt --ask-vault-password \
   inventory/group_vars/mailservers/vault.yml
```

### 4. Configure DNS Records

For **each domain** in `mail_virtual_domains`:

```dns
# MX Record
example.com.              IN MX   10 mail.example.com.

# A Records
mail.example.com.         IN A    <server-ip>
autoconfig.example.com.   IN A    <server-ip>
autodiscover.example.com. IN A    <server-ip>

# PTR Record (at your hosting provider)
<server-ip>               IN PTR  mail.example.com.

# SPF Records
example.com.              IN TXT  "v=spf1 mx -all"
mail.example.com.         IN TXT  "v=spf1 a -all"
```

> **Note:** DNS records can be added later. Postsible automatically uses self-signed certificates for domains where DNS is not yet set up, and upgrades to Let's Encrypt automatically once DNS is in place.

**After deployment** (DKIM keys are generated):

```dns
# DKIM Record (key from /root/dkim-dns-records.txt on server)
dkim._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=MIIBIj..."

# DMARC Record
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; adkim=s; aspf=s"
```

Repeat for every additional domain.

### 5. Start Deployment

```bash
# Complete deployment
ansible-playbook playbooks/site.yml --ask-vault-pass

# Or phase by phase
ansible-playbook playbooks/site.yml --tags phase1 --ask-vault-pass
# ...
```

### 6. Admin User Credentials

```bash
cat /root/admin-credentials.txt
# Save password, then:
rm /root/admin-credentials.txt
```

---

## 📋 System Requirements

- **OS:** Debian 13 (Trixie) — fresh installation
- **RAM:** At least 2 GB
- **Disk:** 20 GB disk space
- **Access:** Root access via SSH
- **Network:** Public IPv4 address
- **DNS:** At least MX + A record per domain before deployment (autoconfig/autodiscover optional, can be added later)

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
- **postfix** - SMTP server with multi-domain support
- **dovecot** - IMAP/POP3 with Sieve support

### Phase 3: Spam Filter
```bash
ansible-playbook playbooks/site.yml --tags phase3 --ask-vault-pass
```
- **rspamd** - Spam filter, DKIM signing per domain, Bayes learning
- **eset_icap** - Antivirus scanner (optional)

### Phase 4: Web & SSL
```bash
ansible-playbook playbooks/site.yml --tags phase4 --ask-vault-pass
```
- **nginx** - Per-domain vhosts with intelligent SSL detection
- **certbot** - Let's Encrypt per domain (self-signed fallback)
- **snappymail** - Webmail on all domains
- **baikal** - CalDAV/CardDAV server
- **infcloud** - Web CalDAV/CardDAV client
- **autoconfig** - Per-domain mail client autoconfiguration

### Phase 5: Security
```bash
ansible-playbook playbooks/site.yml --tags phase5 --ask-vault-pass
```
- **fail2ban** - Brute-force protection (6 jails)

### Phase 6: User Features
```bash
ansible-playbook playbooks/site.yml --tags phase6 --ask-vault-pass
```
- **vacation** - Out-of-office auto-reply manager
- **signature** - Email signature manager

---

## 🎯 Run Individual Roles

```bash
# Update only Postfix
ansible-playbook playbooks/site.yml --tags postfix --ask-vault-pass

# Renew/upgrade SSL certificates (after DNS changes)
ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass

# Reconfigure only rspamd
ansible-playbook playbooks/site.yml --tags rspamd-configure --ask-vault-pass

# Update only Vacation Manager
ansible-playbook playbooks/site.yml --tags vacation --ask-vault-pass

# Update only Signature Manager
ansible-playbook playbooks/site.yml --tags signature --ask-vault-pass

# Update autoconfig/autodiscover for all domains
ansible-playbook playbooks/site.yml --tags autoconfig --ask-vault-pass
```

---

## 🔐 Security Features

### Per-Domain SSL Certificates

Each `mx_hostname`, `autoconfig.<domain>` and `autodiscover.<domain>` gets its own certificate. The certbot role loops over all configured domains and handles each independently:

- If DNS is set → Let's Encrypt certificate
- If DNS is missing → self-signed fallback, marker written to `/var/lib/postsible/certs/<hostname>.pending`
- On next certbot run with DNS set → automatic upgrade to Let's Encrypt

Check certificate status at any time:

```bash
# On the server
ls /var/lib/postsible/certs/
# *.ok      = Let's Encrypt active
# *.pending = self-signed, DNS not yet set
```

### Fail2ban Jails
- **SSH** - Protection against brute-force on port 22
- **Postfix SASL** - Auth failures during mail sending
- **Dovecot** - IMAP/POP3 login failures
- **Nginx HTTP Auth** - Web server authentication
- **SnappyMail** - Webmail login failures
- **Rspamd** - WebUI protection (optional)

### DKIM/SPF/DMARC
- Automatic DKIM key generation (2048-bit) **per domain**
- ARC signing enabled
- Strict DMARC policy (configurable)

---

## 🌐 Access URLs

After successful deployment, every configured domain exposes the same set of URLs:

### Per-domain services

| Service | URL |
|---|---|
| Webmail | `https://mail.<domain>/wm/` |
| Vacation Manager | `https://mail.<domain>/vacation/` |
| Signature Manager | `https://mail.<domain>/signature/` |
| Rspamd WebUI | `https://mail.<domain>/rspamd/` |
| Baikal CalDAV/CardDAV | `https://mail.<domain>/dav/` |
| InfCloud Calendar | `https://mail.<domain>/cal/` |

### IMAP / SMTP

| Protocol | Server | Port | Encryption |
|---|---|---|---|
| IMAP | `mail.<domain>` | 993 | SSL/TLS |
| SMTP Submission | `mail.<domain>` | 587 | STARTTLS |
| SMTP (legacy) | `mail.<domain>` | 465 | SSL/TLS |

---

## ✈️ Vacation Manager

Postsible includes a fully integrated vacation/out-of-office reply system based on **Dovecot Sieve**. Replies are handled entirely server-side — no mail client needs to be running.

The Vacation Manager is accessible on **every configured domain**:

```
https://mail.example.com/vacation/
https://mail.myotherdomain.com/vacation/
```

Users log in with their regular mail credentials. The interface has three access levels:

| Role | Can do |
|---|---|
| **User** | Set/update/disable own vacation reply |
| **Admin** | Manage vacation for all users |
| **Superadmin** | Admin management + grant/revoke admin roles |

### How It Works

- Vacation replies are implemented as Sieve scripts (`.dovecot.sieve`) in each user's home directory
- Each sender receives **at most one auto-reply per week**
- The active period (from/to dates) is enforced by the Sieve script itself
- All settings are stored in MariaDB (`vacation_status` table) and on disk simultaneously

### CLI Usage

```bash
maildb-manage set-vacation user@example.com \
    --from 2026-04-01 \
    --to 2026-04-14 \
    --subject "Out of office: John Doe" \
    --message "I am on vacation until April 14th."

maildb-manage get-vacation user@example.com
maildb-manage disable-vacation user@example.com
```

### Required Dovecot Sieve Extensions

```
sieve_extensions = fileinto mailbox vacation vacation-seconds relational date envelope comparator-i ascii-numeric imap4flags
```

Both `date` (for the from/to date range) and `envelope` (for filtering no-reply senders) are required.

---

## ✍️ Signature Manager

Postsible includes a per-user email signature system that automatically appends HTML (and plain-text) signatures to all **outbound** mail via an rspamd postfilter module.

The Signature Manager is accessible on **every configured domain**:

```
https://mail.example.com/signature/
https://mail.myotherdomain.com/signature/
```

### Features

- **WYSIWYG HTML editor** (Quill.js) with live preview
- **Logo/image upload** — PNG, JPG or SVG (automatically resized and optimized via PHP GD)
- **Plain-text version** generated automatically from HTML (no manual effort)
- **Domain-wide default signatures** as fallback for users without a personal signature
- **Pre-fill from domain default** — users opening the editor for the first time see the domain default as a starting point
- **Admin overview** — admins can edit signatures for all users and manage domain defaults
- **Inline image embedding** — logo is embedded as `cid:` inline attachment

### Signature lookup order (per outbound mail)

```
1. User has a personal signature?  → use it
2. No personal signature, but domain has a default?  → use domain default
3. Neither?  → mail passes unmodified
```

Only mails leaving the server to **external recipients** are modified. Internal mail and inbound mail are never touched.

### Signature storage

```
/etc/rspamd/signatures/
├── users/
│   ├── user@example.com/
│   │   ├── signature.html
│   │   ├── signature.txt    (auto-generated)
│   │   └── logo.png         (optional)
│   └── ...
└── domains/
    ├── example.com/
    │   ├── signature.html
    │   ├── signature.txt
    │   └── logo.png
    └── myotherdomain.com/
        └── ...
```

### Access levels

| Role | Can do |
|---|---|
| **User** | Edit own signature and upload own logo |
| **Admin** | Edit signatures for all users + manage domain defaults |
| **Superadmin** | Admin management + grant/revoke admin roles |

### Thunderbird Integration

Both the Vacation Manager and Signature Manager are available directly from the **Postsible Tools** Thunderbird extension (`postsible-tools.xpi`), downloadable from the vacation manager page. The extension adds two buttons to the SnappyMail sidebar and opens both tools as an overlay without leaving the webmail interface.

---

## 🔑 Admin User Setup

### Automatic Creation

During deployment, Postsible automatically creates an admin user with:
- **Email:** Your configured `mail_admin_email` (default: `admin@example.com`)
- **Password:** Auto-generated secure 20-character password
- **Credentials saved to:** `/root/admin-credentials.txt`

**After first login:**
1. Save the password to your password manager
2. Delete the credentials file: `rm /root/admin-credentials.txt`
3. Optionally change the password: `maildb-manage change-password admin@example.com`

---

## 🛠️ Manage Virtual Domains & Users

### Using maildb-manage (recommended)

```bash
# Add user
maildb-manage add-user user@example.com --displayname 'John Doe' --auto-password

# Add user to additional domain
maildb-manage add-user user@myotherdomain.com --auto-password

# Change password
maildb-manage change-password user@example.com --auto-password

# Remove user
maildb-manage remove-user user@example.com --force
```

### Domain Management

```bash
# List all configured domains
maildb-manage list-domains

# Add a domain (database only — also update vars.yml and re-run playbook!)
maildb-manage add-domain newdomain.com

# Remove domain (WARNING: deletes all users!)
maildb-manage remove-domain olddomain.com --force
```

> **Important for multi-domain:** Adding a domain via `maildb-manage add-domain` only updates the database. To get nginx vhosts, SSL certificates, autoconfig and DKIM for a new domain, add it to `mail_virtual_domains` in `vars.yml` and re-run the playbook.

### Alias Management

```bash
maildb-manage add-alias sales@example.com john@example.com
maildb-manage list-aliases
maildb-manage remove-alias sales@example.com
```

### Vacation Admin Management

```bash
maildb-manage add-vacation-admin secretary@example.com --granted-by admin@example.com
maildb-manage remove-vacation-admin secretary@example.com
maildb-manage list-vacation-admins
maildb-manage set-superadmin admin@example.com
```

---

## 📅 Calendar & Contacts (InfCloud + Baikal)

**InfCloud** (primary web access): `https://mail.<domain>/cal/`

**Baikal** (backend for mobile/desktop sync):

| Platform | Setup |
|---|---|
| iOS/macOS | Settings → Accounts → Other → CalDAV/CardDAV → `mail.<domain>/dav` |
| Android | DAVx⁵ → `https://mail.<domain>/dav/dav.php/` |
| Thunderbird | TbSync + CalDAV/CardDAV Provider → `https://mail.<domain>/dav/dav.php/` |

Baikal accounts, calendars and addressbooks are created automatically when users are added via `maildb-manage add-user`.

---

## 📁 Project Structure

```
postsible/
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       └── mailservers/
│           ├── vars.yml          # Public variables (multi-domain config here)
│           └── vault.yml         # Encrypted secrets
├── roles/
│   ├── common/
│   ├── ufw/
│   ├── mariadb/
│   ├── postfix/
│   ├── dovecot/
│   ├── rspamd/
│   ├── nginx/                    # Per-domain vhost generation
│   ├── certbot/                  # Per-domain SSL (LE + self-signed fallback)
│   ├── autoconfig/               # Per-domain autoconfig + autodiscover
│   ├── snappymail/               # Webmail (injected into every domain vhost)
│   ├── baikal/
│   ├── infcloud/
│   ├── vacation/                 # Vacation manager (every domain vhost)
│   ├── signature/                # Signature manager (every domain vhost)
│   ├── fail2ban/
│   └── eset_icap/
├── playbooks/
│   ├── site.yml
│   └── maintenance.yml
├── setup.sh                      # Interactive setup with multi-domain support
└── README.md
```

---

## 🔧 Maintenance

### Check Logs

```bash
tail -f /var/log/mail/mail.log
tail -f /var/log/rspamd/rspamd.log
tail -f /var/log/nginx/mail.example.com-https-access.log
tail -f /var/log/php8.4-fpm-vacation.log
tail -f /var/log/php8.4-fpm-signature.log

# Sieve script errors (per user)
cat /srv/imap/DOMAIN/USERNAME/.dovecot.sieve.log
```

### Add a New Domain to an Existing Installation

```bash
# 1. Add to vars.yml
vim inventory/group_vars/mailservers/vars.yml
# → Add entry to mail_virtual_domains list

# 2. Set DNS records for the new domain
# (MX, A, autoconfig, autodiscover, SPF)

# 3. Re-run the playbook
ansible-playbook playbooks/site.yml --ask-vault-pass
# Or only the affected roles:
ansible-playbook playbooks/site.yml \
    --tags "nginx,certbot,autoconfig,snappymail,vacation,signature,rspamd-dkim" \
    --ask-vault-pass

# 4. Add DKIM record to DNS
cat /root/dkim-dns-records.txt

# 5. If DNS was not ready, upgrade certs later:
ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass
```

### Upgrade Self-Signed to Let's Encrypt

Once DNS records are set for a domain that previously used self-signed certificates:

```bash
ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass
```

The certbot role automatically detects which hostnames now resolve correctly and replaces only those self-signed certificates.

### Check Certificate Status

```bash
# Quick overview
ls /var/lib/postsible/certs/
# *.ok      → Let's Encrypt active
# *.pending → self-signed, DNS not yet pointing here

# Detailed info for a specific cert
openssl x509 -in /etc/letsencrypt/live/mail.example.com/fullchain.pem \
    -noout -subject -issuer -dates
```

### Spam Learning

Users move messages to train rspamd:
- `.Spam/` folder → trained as spam
- `.Ham/` folder → trained as ham (false positive)

Cronjob runs every 30 minutes + daily at 3:00 AM.

---

## 🐛 Troubleshooting

### New Domain Not Working

```bash
# Check nginx vhost exists
ls /etc/nginx/sites-enabled/ | grep <domain>

# Check SSL cert status
ls /var/lib/postsible/certs/ | grep <hostname>

# Check nginx config
nginx -t

# Check DNS
dig +short mail.newdomain.com A
dig +short autoconfig.newdomain.com A
```

### Self-Signed Certificate Still Active After DNS Change

```bash
# Verify DNS resolves to this server
dig +short mail.example.com A
curl -s https://api.ipify.org

# If they match, re-run certbot
ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass

# Check result
cat /var/lib/postsible/certs/mail.example.com.ok  # should exist now
```

### Webmail Not Accessible on a Domain

```bash
# Check vhost and SnappyMail block are present
grep -A5 "SnappyMail" /etc/nginx/sites-available/mail.example.com.conf

# If missing, re-run snappymail role
ansible-playbook playbooks/site.yml --tags snappymail --ask-vault-pass
```

### Signature Not Being Appended

```bash
# Check rspamd Lua module is loaded
rspamadm configtest 2>&1 | grep -i signature

# Check signature files exist
ls /etc/rspamd/signatures/users/user@example.com/

# Check rspamd postfilter log
journalctl -u rspamd -n 50 | grep -i signature

# Restart rspamd
systemctl restart rspamd
```

### Vacation Reply Not Sent

```bash
# 1. Check Sieve script exists and compiled
ls -la /srv/imap/DOMAIN/USERNAME/.dovecot.sieve
ls -la /srv/imap/DOMAIN/USERNAME/.dovecot.svbin

# 2. Check for compilation errors
cat /srv/imap/DOMAIN/USERNAME/.dovecot.sieve.log

# 3. Manually recompile
sievec /srv/imap/DOMAIN/USERNAME/.dovecot.sieve

# 4. Check vacation status
maildb-manage get-vacation user@example.com
```

### DKIM Not Working for a Domain

```bash
# Check DKIM key exists for domain
ls -la /var/lib/rspamd/dkim/

# Check DNS record
dig TXT dkim._domainkey.example.com +short

# Restart rspamd
systemctl restart rspamd

# Test with
tail -f /var/log/rspamd/rspamd.log | grep -i dkim
```

### Mail Marked as Spam

```bash
dig TXT example.com +short                    # SPF
dig TXT dkim._domainkey.example.com +short    # DKIM
dig TXT _dmarc.example.com +short             # DMARC
dig -x <server-ip> +short                     # PTR / Reverse DNS

# Online test
# https://www.mail-tester.com/
# https://mxtoolbox.com/SuperTool.aspx
```

### Baikal Not Working

```bash
systemctl status php8.4-fpm
nginx -t
ls -la /var/www/baikal/        # should be www-data:www-data
maildb-manage check             # sync check
```

---

## 🔄 Backup

```bash
# MariaDB (mail users, vacation, signature admins, Baikal data)
mysqldump -u root -p mailserver > mailserver-backup.sql

# Mailboxes + Sieve scripts
tar czf mailboxes-backup.tar.gz /srv/imap/

# Signatures
tar czf signatures-backup.tar.gz /etc/rspamd/signatures/

# Baikal data
tar czf baikal-backup.tar.gz /var/www/baikal/Specific/

# Configuration
tar czf config-backup.tar.gz \
    /etc/postfix /etc/dovecot /etc/rspamd \
    /etc/nginx/sites-available /etc/letsencrypt \
    /var/lib/postsible/certs
```

---

## 🤝 Known Issues & Solutions

### rspamd Neural Network Crashes
**Problem:** Neural network module causes segmentation faults  
**Solution:** Neural network is disabled by default (`rspamd_enable_neural: false`). Bayes filter alone handles 95% of spam detection.

### sign_headers Causes DKIM Crash
**Problem:** Custom `sign_headers` list leads to rspamd crash  
**Solution:** Removed from template — rspamd uses sensible defaults.

### Baikal Calendars Not Deleted
**Problem:** Manual user deletion leaves Baikal data behind  
**Solution:** Always use `maildb-manage remove-user` — it removes all Baikal data automatically.

### Vacation Reply Not Working After Setup
**Problem:** Sieve script exists but no reply is sent  
**Solution:** Verify both `date` and `envelope` are listed in `sieve_extensions` in `/etc/dovecot/conf.d/90-sieve.conf`.

### Signature Not Appended on First Send
**Problem:** Signature files exist but rspamd doesn't pick them up  
**Solution:** Restart rspamd after saving a new signature: `systemctl restart rspamd`. The Lua postfilter reads files from disk and may cache directory listings briefly.

### Old `rspamd` nginx vhost Conflicts
**Problem:** After migrating from a single-domain setup, the old `/etc/nginx/sites-available/rspamd` vhost conflicts with the new per-domain vhosts  
**Solution:** The nginx role removes this file automatically. If you migrated manually, remove it:
```bash
rm /etc/nginx/sites-enabled/rspamd
rm /etc/nginx/sites-available/rspamd
nginx -t && systemctl reload nginx
```

---

## 📚 Further Documentation

- **Rspamd:** https://rspamd.com/doc/
- **Postfix:** http://www.postfix.org/documentation.html
- **Dovecot:** https://doc.dovecot.org/
- **Dovecot Sieve:** https://doc.dovecot.org/configuration_manual/sieve/
- **SnappyMail:** https://snappymail.eu/
- **Baikal:** https://sabre.io/baikal/
- **fail2ban:** https://github.com/fail2ban/fail2ban/wiki

---

## 📜 License

MIT License — see [LICENSE](LICENSE) file

---

## 🙏 Credits

Developed as a comprehensive mail server solution focusing on:
- **Security** (DKIM per domain, SPF, DMARC, fail2ban, SSL per hostname)
- **Multi-domain** (every domain is a first-class citizen, no hardcoded primary vhost)
- **User-friendliness** (interactive setup, autoconfig/autodiscover, vacation manager, signature manager)
- **Maintainability** (Ansible, modular structure, self-signed fallback, good documentation)
- **Production-readiness** (tested, stable, best practices)

---

## 💡 Support

For issues:
1. Check logs (`/var/log/mail/`, `/var/log/rspamd/`, `/var/log/nginx/`)
2. Check service status (`systemctl status postfix dovecot rspamd php8.4-fpm nginx`)
3. Check certificate markers (`ls /var/lib/postsible/certs/`)
4. Create GitHub issues: https://github.com/grufocom/postsible/issues
