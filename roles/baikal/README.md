# Baïkal Ansible Role

This role installs and configures Baïkal, a lightweight CalDAV and CardDAV server.

## Features

- CalDAV (Calendar) support
- CardDAV (Contacts) support
- Multi-user support
- MySQL/MariaDB backend
- Nginx integration
- SSL/TLS support via existing certificates

## Requirements

- Nginx (from nginx role)
- PHP-FPM (from nginx role)
- MariaDB (from mariadb role)
- SSL certificates (from certbot role)

## Role Variables

See `defaults/main.yml` for all available variables.

Key variables:
```yaml
baikal_version: "0.11.1"
baikal_install_path: "/var/www/baikal"
baikal_db_name: "baikal"
baikal_cal_enabled: true
baikal_card_enabled: true
```

Vault variables (in `group_vars/vault.yml`):
```yaml
vault_baikal_admin_password: "admin-password"
```

## Dependencies

- nginx
- mariadb

## Example Playbook

```yaml
- hosts: mail_servers
  roles:
    - role: baikal
      tags: baikal
```

## Client Configuration

### iOS/macOS
1. Settings → Passwords & Accounts → Add Account → Other
2. Add CalDAV Account:
   - Server: mail.example.com/dav/
   - Username: your-username
   - Password: your-password

### Android (DAVx⁵)
1. Install DAVx⁵ from F-Droid or Play Store
2. Add account with base URL: https://mail.example.com/dav/

### Thunderbird
1. Install Lightning addon
2. Calendar → New Calendar → On the Network
3. CalDAV URL: https://mail.example.com/dav/cal.php/principals/USERNAME/

## Admin Interface

Access: https://mail.example.com/dav/admin/
Username: admin
Password: (from vault_baikal_admin_password)

## License

MIT

## Author

Postsible Team
