# SnappyMail MailAdmin Role

Standalone API-based admin interface for Postsible mailserver.

## Features

- Domain Management (list, add, remove)
- User Management (list, add, remove, enable/disable, password)
- Alias Management (list, add, remove)
- Sieve Scripts (signatures, vacation messages)
- Floating admin button in SnappyMail
- Session-based authentication

## Installation

Already integrated in site.yml - just run:

```bash
ansible-playbook site.yml --tags snappymail_mailadmin
```

## Usage

1. Login to SnappyMail as admin@example.com
2. Click the "⚙️ Admin" button (bottom right)
3. Manage domains, users, aliases

## Files

- `tasks/main.yml` - Ansible deployment tasks
- `templates/admin-api.php.j2` - PHP API (with Ansible vars)
- `files/mailadmin.js` - JavaScript frontend
- `files/mailadmin.css` - Styling
- `files/MailDB.php` - Database operations
- `files/SieveManager.php` - Sieve management

## Architecture

```
SnappyMail Plugin (minimal) → JavaScript → Standalone PHP API → MySQL/Sieve
```

## Variables

From `group_vars/mailservers/vars.yml`:
- `mail_admin_email` - Admin email(s)
- `mariadb_host` - Database host
- `mariadb_database` - Database name
- `mariadb_root_password` - Database password (from vault)
- `postfix_myhostname` - Server hostname
- `dovecot_mail_location` - Maildir path

## Security

- Session validation
- Admin email whitelist
- PDO prepared statements
- Password hashing (SHA512-CRYPT)
- POST-only API

## Support

Logs:
- `/var/log/nginx/error.log`
- `/var/log/php8.4-fpm.log`
- `/var/www/snappymail/data/_data_/_default_/logs/`
