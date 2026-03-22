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
- **✈️ Vacation Manager** - Out-of-office auto-replies with web interface & CLI
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
# start with a plain debian 13 server system like you get from nearly every hosting service
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

### 5. Post-Setup Configuration
After running the interactive setup (./setup.sh --interactive), your basic configuration is stored in:

```bash
inventory/group_vars/mailservers/vars.yml
```

This file contains all essential settings for your mail server. You can (and should) review and adjust additional parameters to fine-tune your installation.


### 6. Start Deployment

```bash
# Complete deployment
ansible-playbook playbooks/site.yml --ask-vault-pass

# Or phase by phase
ansible-playbook playbooks/site.yml --tags phase1 --ask-vault-pass
ansible-playbook playbooks/site.yml --tags phase2 --ask-vault-pass
# etc.
```

### 7. Admin User Credentials

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
- **certbot** - Let's Encrypt SSL certificates (with self-signed fallback)
- **snappymail** - Webmail interface
- **baikal** - CalDAV/CardDAV server
- **infcloud** - Web CalDAV/CardDAV client

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

# Update only Vacation Manager
ansible-playbook playbooks/site.yml --tags vacation --ask-vault-pass
```

---

## 🔐 Security Features

### Intelligent SSL Detection
Postfix and Nginx automatically detect Let's Encrypt certificates:
1. Preferred: `/etc/letsencrypt/live/mail.example.com/`
2. Fallback: `/etc/letsencrypt/live/example.com/`
3. Fallback: Snakeoil (testing only)

### Self-Signed Certificate Fallback

When preparing a new mail server while DNS still points to the old server, Postsible automatically detects this situation and falls back to a self-signed certificate so all services are immediately operational.

**How it works:**

During deployment the certbot role resolves the primary domain (`certbot_domains[0]`) via DNS and compares the result against the server's public IP. If they don't match — or if `certbot_skip: true` is set — a self-signed certificate is generated instead:

```
Domain resolves to this server? ──yes──► Let's Encrypt (normal flow)
                                  └─no──► Self-signed certificate
                                          (services work, clients show warning)
```

The self-signed certificate is created with the correct CN and SAN entries so clients at least display the right hostname. A marker file at `/etc/postsible/certbot-pending` is written as a reminder.

**Once DNS is switched**, simply re-run the certbot role — it detects the DNS change, obtains a real certificate, and replaces the self-signed one automatically:

```bash
ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass
```

**Variables** (in `inventory/group_vars/mailservers/vars.yml`):

```yaml
# Skip certbot and always use self-signed (useful when DNS is not ready)
certbot_skip: false

# Automatically check DNS before running certbot (recommended: true)
certbot_dns_check: true
```

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

**Vacation Manager:**
- URL: `https://mail.example.com/vacation/`
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

The `maildb-manage` script supports both **interactive** and **non-interactive** (CLI parameters) usage and automatically synchronizes with Baikal.

#### Interactive Mode (prompts for input)

```bash
# Add user - will prompt for password and display name
maildb-manage add-user user@example.com

# Change password - will prompt for new password
maildb-manage change-password user@example.com

# Remove user - will ask for confirmation
maildb-manage remove-user user@example.com
```

#### Non-Interactive Mode (CLI parameters)

**Add Users:**

```bash
# With specific password
maildb-manage add-user user@example.com --password 'MySecurePass123!'

# With auto-generated password (shows password on screen)
maildb-manage add-user user@example.com --auto-password

# With display name and auto-password
maildb-manage add-user user@example.com --displayname 'John Doe' --auto-password

# Quiet mode (only outputs password - useful for scripts)
PASSWORD=$(maildb-manage add-user user@example.com --auto-password --quiet)
echo "Password: $PASSWORD"
```

**Change Passwords:**

```bash
# Set specific password
maildb-manage change-password user@example.com --password 'NewPassword123!'

# Auto-generate new password
maildb-manage change-password user@example.com --auto-password
```

**Remove Users/Domains/Aliases (skip confirmation):**

```bash
# Remove without confirmation prompt
maildb-manage remove-user user@example.com --force
maildb-manage remove-domain old-domain.com --force
maildb-manage remove-alias alias@example.com --force
```

#### Domain Management

```bash
# Add domain
maildb-manage add-domain newdomain.com

# List all domains
maildb-manage list-domains

# Remove domain (WARNING: deletes all users!)
maildb-manage remove-domain olddomain.com
```

#### User Management

```bash
# List all users (shows Baikal sync status)
maildb-manage list-users

# List users for specific domain
maildb-manage list-users example.com

# Enable/disable user
maildb-manage enable-user user@example.com
maildb-manage disable-user user@example.com

# Repair Maildir structure
maildb-manage create-maildir user@example.com
```

#### Alias Management

```bash
# Add alias
maildb-manage add-alias sales@example.com john@example.com

# List all aliases
maildb-manage list-aliases

# List aliases for specific domain
maildb-manage list-aliases example.com

# Remove alias
maildb-manage remove-alias sales@example.com
```

#### Vacation / Out-of-Office Management

```bash
# Set vacation reply for a user
maildb-manage set-vacation user@example.com \
    --from 2026-04-01 \
    --to 2026-04-14 \
    --subject "Out of office: John Doe" \
    --message "I am on vacation until April 14th. For urgent matters please contact info@example.com."

# Show current vacation settings
maildb-manage get-vacation user@example.com

# Disable vacation reply
maildb-manage disable-vacation user@example.com
```

#### Vacation Admin Management

```bash
# Grant vacation-admin role (can manage vacation for all users)
maildb-manage add-vacation-admin user@example.com --granted-by admin@example.com

# Revoke vacation-admin role
maildb-manage remove-vacation-admin user@example.com

# List all vacation admins
maildb-manage list-vacation-admins

# Set a user as vacation superadmin (can also manage admin roles)
maildb-manage set-superadmin admin@example.com
```

#### Statistics & Checks

```bash
# Show database statistics (incl. active vacation replies)
maildb-manage stats

# Check database integrity (Mail + Baikal sync + Sieve scripts)
maildb-manage check

# Help
maildb-manage help
```

### Bulk User Creation (Script Example)

Create multiple users automatically:

```bash
#!/bin/bash
# Create users from list
# Format: email,displayname

cat << 'EOF' > users-to-create.txt
john.doe@example.com,John Doe
jane.smith@example.com,Jane Smith
bob.johnson@example.com,Bob Johnson
EOF

while IFS=, read -r email displayname; do
    echo "Creating user: $email"
    PASSWORD=$(maildb-manage add-user "$email" \
        --displayname "$displayname" \
        --auto-password \
        --quiet)
    echo "$email,$PASSWORD" >> /root/new-users.csv
done < users-to-create.txt

echo "All users created! Passwords saved to /root/new-users.csv"
echo "IMPORTANT: Send passwords securely to users, then delete the file!"
echo "rm /root/new-users.csv"
```

### Common Workflows

**Onboarding New User:**

```bash
# 1. Create user with auto-password
PASSWORD=$(maildb-manage add-user john.doe@example.com \
    --displayname 'John Doe' \
    --auto-password)

# 2. Send credentials securely (e.g., via encrypted email or password manager)
echo "Email: john.doe@example.com"
echo "Password: $PASSWORD"
echo "Webmail: https://mail.example.com/wm/"
echo "Calendar: https://mail.example.com/cal/"
echo "Vacation: https://mail.example.com/vacation/"

# 3. User can change password after first login via SnappyMail settings
```

**Setting Up Department Aliases:**

```bash
# Add users
maildb-manage add-user john@company.com --auto-password
maildb-manage add-user jane@company.com --auto-password
maildb-manage add-user bob@company.com --auto-password

# Create department aliases
maildb-manage add-alias sales@company.com john@company.com
maildb-manage add-alias support@company.com jane@company.com
maildb-manage add-alias info@company.com bob@company.com
```

**Password Reset:**

```bash
# Generate new password for user
maildb-manage change-password user@example.com --auto-password

# Or set specific password
maildb-manage change-password user@example.com --password 'NewSecurePass123!'
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

## 🔒 Security Best Practices

### Password Management

**Auto-Generated Passwords:**
- Postsible generates secure 20-character passwords
- Mix of uppercase, lowercase, and numbers
- Use `--auto-password` for all new users

**Password Storage:**
- Never store passwords in plain text files long-term
- Use a password manager (KeePass, Bitwarden, 1Password)
- Delete `/root/admin-credentials.txt` after saving
- Delete any CSV files with passwords after distributing

**Password Rotation:**

```bash
# Change password for specific user
maildb-manage change-password user@example.com --auto-password

# Bulk password rotation (use with caution!)
maildb-manage list-users | grep -oP '[\w.-]+@[\w.-]+' | while read email; do
    echo "Resetting password for $email"
    maildb-manage change-password "$email" --auto-password
done
```

### Credential Files

**After deployment, secure these files:**

```bash
# Admin credentials (delete after saving!)
cat /root/admin-credentials.txt  # Save password first!
rm /root/admin-credentials.txt

# DKIM keys (keep these safe!)
cat /root/dkim-dns-records.txt  # Copy to DNS
chmod 600 /var/lib/rspamd/dkim/*.key

# Deployment summary
cat /etc/postsible/deployment_summary.txt
```

---

## 🌐 Access Credentials

After successful deployment:

### Webmail
- **URL:** `https://mail.example.com/wm/`
- **Login:** Complete email address + password

### Vacation Manager
- **URL:** `https://mail.example.com/vacation/`
- **Login:** Complete email address + password (same as webmail)
- **Features:** Set/disable out-of-office replies, admin view of all users, role management

### InfCloud (Web Calendar/Contacts)
- **URL:** https://mail.example.com/cal/
- **Login:** Complete email address + password
- **Features:** Calendar (CalDAV), Contacts (CardDAV), Tasks - browser-based, no app installation needed

### Baikal (CalDAV/CardDAV)
- **URL:** `https://mail.example.com/dav/`
- **Login:** Complete email address + password
- **CalDAV:** `https://mail.example.com/dav/dav.php/calendars/user@example.com/`
- **CardDAV:** `https://mail.example.com/dav/dav.php/addressbooks/user@example.com/`

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

🎉 **InfCloud - Web Client (Primary Access)**

https://mail.example.com/cal/

Login: user@example.com + password

✅ Calendars & Events
✅ Contacts management
✅ Tasks/Todos
✅ Mobile-friendly
✅ Multi-user ready
✅ Automatic user provisioning via maildb-manage

🔧 **Baikal - Server Backend (Mobile/Desktop Sync)**

For native apps (iOS, Android, Thunderbird, Outlook)

### Client Configuration

#### iOS/macOS
1. **Settings → Accounts → Add Account**
2. **Other → CalDAV/CardDAV Account**
3. **Server:** `mail.example.com/dav`
4. **Username:** Complete email address
5. **Password:** Your mail password

#### Thunderbird
1. **Install add-on:** TbSync + Provider for CalDAV & CardDAV
2. **Add account → CalDAV & CardDAV**
3. **Server:** `https://mail.example.com/dav/dav.php/`
4. **Username:** Email address

#### Android
- **DAVx⁵** from F-Droid/Play Store
- **Base URL:** `https://mail.example.com/dav/dav.php/`
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

## ✈️ Vacation Manager (Out-of-Office Replies)

Postsible includes a fully integrated vacation/out-of-office reply system based on **Dovecot Sieve**. Replies are handled entirely server-side — no mail client needs to be running.

### How It Works

- Vacation replies are implemented as Sieve scripts (`.dovecot.sieve`) in each user's home directory
- Each sender receives **at most one auto-reply per week**, regardless of how many mails they send
- The active period (from/to dates) is enforced by the Sieve script itself
- All settings are stored in MariaDB (`vacation_status` table) and on disk simultaneously

### Web Interface

**URL:** `https://mail.example.com/vacation/`

Users log in with their regular mail credentials. The interface has three access levels:

| Role | Can do |
|------|--------|
| **User** | Set/update/disable own vacation reply |
| **Admin** | Manage vacation for all users |
| **Superadmin** | Admin management + grant/revoke admin roles |

The first superadmin is set automatically during deployment (`mail_admin_email`).

### CLI Usage

```bash
# Set vacation reply
maildb-manage set-vacation user@example.com \
    --from 2026-04-01 \
    --to 2026-04-14 \
    --subject "Out of office: John Doe" \
    --message "I am on vacation until April 14th. For urgent matters please contact info@example.com."

# Check current status
maildb-manage get-vacation user@example.com

# Disable vacation reply
maildb-manage disable-vacation user@example.com

# Admin role management
maildb-manage add-vacation-admin secretary@example.com --granted-by admin@example.com
maildb-manage remove-vacation-admin secretary@example.com
maildb-manage list-vacation-admins
maildb-manage set-superadmin admin@example.com
```

### Required Dovecot Sieve Extensions

The following extensions must be enabled in your Dovecot Sieve configuration (`90-sieve.conf`):

```
sieve_extensions = fileinto mailbox vacation vacation-seconds relational date envelope comparator-i ascii-numeric imap4flags
```

**Important:** Both `date` (for the from/to date range check) and `envelope` (for filtering no-reply senders) are required. Without them, the Sieve script will fail to compile and no auto-reply will be sent. Check the Sieve log if replies are not working:

```bash
cat /srv/imap/DOMAIN/USERNAME/.dovecot.sieve.log
```

### Architecture

```
User/Admin → Web Interface (PHP)
                  ↓ sudo
            maildb-manage set-vacation
                  ↓
    writes → .dovecot.sieve  (Sieve script, picked up by Dovecot on next mail delivery)
    writes → vacation_status  (MariaDB, for web interface display)
```

The PHP web interface runs in a **dedicated PHP-FPM pool** (`vacation`) with `exec()` enabled (required for `sudo maildb-manage` calls), while the main `www` pool remains fully locked down.

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

# Vacation Manager PHP errors
tail -f /var/log/php8.4-fpm-vacation.log

# Sieve script compilation errors (per user)
cat /srv/imap/DOMAIN/USERNAME/.dovecot.sieve.log
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
systemctl status php8.4-fpm
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

Postsible supports subaddressing using the + symbol. This allows users to add arbitrary suffixes to their email addresses without creating new mailboxes.

**Example:**
Primary address: `hans.meiser@domain.com`
Subaddress: `hans.meiser+newsletter@domain.com`

All emails will automatically be delivered to the hans.meiser mailbox.

**Use Cases:**
- Filter emails by project, newsletter, or source
- Track where emails originate from
- No extra database entries or mailbox management required

**Technical Details:**

Postfix: `main.cf` contains `recipient_delimiter = +`
Dovecot: `10-mail.conf` contains `mailbox_delimiter = +`

**SQL Maps:** virtual-mailbox-maps, virtual-alias-maps, email2email handle the stripping of the + suffix
Dovecot SQL Queries: `%{u}@%{d}` ensures correct user resolution

**Admin Examples:**

```bash
# Test email locally with Postfix
echo "Test mail" | sendmail hans.meiser+1234@domain.com

# Fetch mail via Dovecot
doveadm fetch text subject hans.meiser+abc@domain.com
```

**Sieve Filtering Example:**

```sieve
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

Each virtual domain gets its own autoconfig subdirectory:

```
/var/www/autoconfig/<domain>/mail/config-v1.1.xml
```

Thunderbird / Lightning expects the XML at:

```
https://autoconfig.example.com/mail/config-v1.1.xml
```

Certbot automatically requests certificates for the autoconfig subdomain.
Nginx handles both HTTP → HTTPS redirection and serving of autoconfig files.

**Example structure for multiple domains:**

```
/var/www/autoconfig/
├── example.com/
│   └── mail/config-v1.1.xml
├── example.net/
│   └── mail/config-v1.1.xml
```

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

### Can't Login to Webmail

```bash
# Check if user exists
maildb-manage list-users | grep your-email@example.com

# Check Baikal sync status
maildb-manage check

# Reset password
maildb-manage change-password your-email@example.com --auto-password

# Check Dovecot authentication
doveadm auth test your-email@example.com
```

### Lost Admin Password

```bash
# Generate new password for admin
maildb-manage change-password admin@example.com --auto-password

# Or set specific password
maildb-manage change-password admin@example.com --password 'NewSecurePass123!'
```

### Vacation Reply Not Sent

```bash
# 1. Check if Sieve script exists and was compiled
ls -la /srv/imap/DOMAIN/USERNAME/.dovecot.sieve
ls -la /srv/imap/DOMAIN/USERNAME/.dovecot.svbin

# 2. Check compilation log for errors
cat /srv/imap/DOMAIN/USERNAME/.dovecot.sieve.log

# 3. Manually recompile the script
sievec /srv/imap/DOMAIN/USERNAME/.dovecot.sieve

# 4. Check vacation status in database
maildb-manage get-vacation user@example.com
```

### Baikal Not Working
```bash
# Check PHP-FPM status
systemctl status php8.4-fpm

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
curl -I https://mail.example.com/.well-known/caldav
curl -I https://mail.example.com/.well-known/carddav
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
│   ├── vacation/                           # Out-of-office reply manager
│   │   ├── defaults/main.yml               # Configuration defaults
│   │   ├── handlers/main.yml               # Service reload handlers
│   │   ├── tasks/main.yml                  # Deployment tasks
│   │   └── templates/
│   │       ├── index.php.j2                # Web interface
│   │       ├── php-fpm-vacation.conf.j2    # Dedicated PHP-FPM pool
│   │       └── postsible-vacation.sudoers.j2 # sudo rules for web interface
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
# MariaDB (incl. Baikal data and vacation settings)
mysqldump -u root -p mailserver > mailserver-backup.sql

# Mailboxes (incl. Sieve scripts)
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

### Vacation Reply Not Working After Setup
**Problem:** Sieve script exists but no reply is sent
**Solution:** Check that both `date` and `envelope` extensions are listed in `sieve_extensions` in `/etc/dovecot/conf.d/90-sieve.conf`. Both are required — `date` for the from/to date range, `envelope` for filtering no-reply senders. Neither is enabled by default in all Dovecot distributions. See [Vacation Reply Not Sent](#vacation-reply-not-sent) for the full checklist.

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

MIT License - see [LICENSE](LICENSE) file

---

## 🙏 Credits

Developed as a comprehensive mail server solution focusing on:
- **Security** (DKIM, SPF, DMARC, fail2ban, SSL)
- **User-friendliness** (Interactive setup, automatic config, CalDAV/CardDAV, vacation manager)
- **Maintainability** (Ansible, modular structure, good documentation)
- **Production-readiness** (Tested, stable, best practices)

---

## 💡 Support

For issues:
1. Check logs (`/var/log/mail/`, `/var/log/rspamd/`, `/var/log/nginx/`, `/var/log/php8.4-fpm-vacation.log`)
2. Check service status (`systemctl status postfix dovecot rspamd php8.4-fpm`)
3. Create GitHub issues: https://github.com/grufocom/postsible/issues
4. Consult community forum

---
