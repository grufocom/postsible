#!/bin/bash
#
# Postsible Mailserver - Complete Uninstall Script
# Removes all components and resets to clean Debian state
#
# Usage: sudo ./uninstall.sh [--yes]
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Auto-confirm flag
AUTO_YES=false
if [[ "$1" == "--yes" ]] || [[ "$1" == "-y" ]]; then
    AUTO_YES=true
fi

echo -e "${RED}======================================"
echo "  POSTSIBLE MAILSERVER UNINSTALL"
echo -e "======================================${NC}"
echo ""
echo "This will remove:"
echo "  - Postfix, Dovecot, Rspamd, Redis"
echo "  - Nginx, PHP-FPM, SnappyMail"
echo "  - MariaDB (including all databases!)"
echo "  - Certbot and SSL certificates"
echo "  - fail2ban"
echo "  - All configuration files"
echo "  - All mail data in /srv/imap/"
echo ""
echo -e "${YELLOW}WARNING: This cannot be undone!${NC}"
echo ""

if [[ "$AUTO_YES" == false ]]; then
    read -p "Are you absolutely sure? (type 'yes' to confirm): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""
echo -e "${GREEN}Starting uninstall...${NC}"
echo ""

# Stop all services
echo "Stopping services..."
systemctl stop postfix 2>/dev/null || true
systemctl stop dovecot 2>/dev/null || true
systemctl stop rspamd 2>/dev/null || true
systemctl stop redis-server 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
systemctl stop php8.4-fpm 2>/dev/null || true
systemctl stop php8.3-fpm 2>/dev/null || true
systemctl stop mariadb 2>/dev/null || true
systemctl stop mysql 2>/dev/null || true
systemctl stop fail2ban 2>/dev/null || true
systemctl stop certbot.timer 2>/dev/null || true

# Disable services
echo "Disabling services..."
systemctl disable postfix 2>/dev/null || true
systemctl disable dovecot 2>/dev/null || true
systemctl disable rspamd 2>/dev/null || true
systemctl disable redis-server 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true
systemctl disable php8.4-fpm 2>/dev/null || true
systemctl disable php8.3-fpm 2>/dev/null || true
systemctl disable mariadb 2>/dev/null || true
systemctl disable fail2ban 2>/dev/null || true

# Remove packages
echo "Removing packages..."
apt-get remove --purge -y \
    postfix \
    postfix-mysql \
    postfix-policyd-spf-python \
    dovecot-core \
    dovecot-imapd \
    dovecot-pop3d \
    dovecot-lmtpd \
    dovecot-mysql \
    dovecot-sieve \
    dovecot-managesieved \
    rspamd \
    redis-server \
    nginx \
    nginx-common \
    php8.4-fpm \
    php8.4-cli \
    php8.4-curl \
    php8.4-intl \
    php8.4-mysql \
    php8.4-xml \
    php8.4-zip \
    php8.3-fpm \
    php8.3-cli \
    php-fpm \
    mariadb-server \
    mariadb-client \
    mariadb-common \
    mysql-common \
    certbot \
    python3-certbot-nginx \
    fail2ban \
    2>/dev/null || true

# Force remove any remaining config files
echo "Removing remaining configuration files..."
dpkg --purge mariadb-server mariadb-client mariadb-common mysql-common 2>/dev/null || true
dpkg --purge postfix dovecot-core nginx php8.4-fpm php8.3-fpm rspamd redis-server fail2ban 2>/dev/null || true

# Remove additional dependencies
apt-get autoremove --purge -y 2>/dev/null || true

# Remove configuration directories
echo "Removing configuration files..."
rm -rf /etc/postfix
rm -rf /etc/dovecot
rm -rf /etc/rspamd
rm -rf /etc/nginx
rm -rf /etc/php
rm -rf /etc/mysql
rm -rf /etc/fail2ban
rm -rf /etc/letsencrypt

# Remove data directories (but keep structure for reinstall)
echo "Removing data directories..."
rm -rf /srv/imap
rm -rf /var/lib/rspamd
rm -rf /var/lib/redis
rm -rf /var/lib/mysql
rm -rf /var/lib/mysql-files
rm -rf /var/lib/mysql-keyring
rm -rf /var/lib/dovecot
rm -rf /var/lib/fail2ban
rm -rf /var/www/snappymail
rm -rf /var/www/html

# Clean mail queue but keep directory structure for reinstall
echo "Cleaning mail queue..."
if [[ -d /var/spool/postfix ]]; then
    find /var/spool/postfix -mindepth 1 -delete 2>/dev/null || true
fi

# Remove run directories
echo "Removing runtime directories..."
rm -rf /var/run/mysqld
rm -rf /var/run/dovecot
rm -rf /run/mysqld

# Remove log files
echo "Removing log files..."
rm -rf /var/log/mail.log*
rm -rf /var/log/mail.err*
rm -rf /var/log/mail.warn*
rm -rf /var/log/rspamd
rm -rf /var/log/nginx
rm -rf /var/log/php*-fpm.log

# Note: We do NOT manually remove users/groups here
# The packages should handle this during purge
# Manually removing them causes dpkg statoverride issues

# Clean up UFW rules (if UFW is installed)
if command -v ufw &> /dev/null; then
    echo "Cleaning UFW rules..."
    ufw --force reset 2>/dev/null || true
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw --force enable
fi

# Remove repository keys and sources
echo "Removing repository configurations..."
rm -f /etc/apt/sources.list.d/rspamd.list
rm -f /etc/apt/keyrings/rspamd.gpg
rm -f /etc/apt/sources.list.d/nginx.list
rm -f /etc/apt/keyrings/nginx.gpg
rm -f /etc/apt/sources.list.d/php.list
rm -f /etc/apt/keyrings/php.gpg

# Update package lists
echo "Updating package lists..."
apt-get update

# Fix dpkg statoverrides (clean up any leftovers from previous installs)
echo "Cleaning dpkg statoverrides for mail-related services..."
for user in vmail rspamd; do
    dpkg-statoverride --list 2>/dev/null | grep " $user " | awk '{print $4}' | while read path; do
        dpkg-statoverride --remove "$path" 2>/dev/null || true
    done
done

# Clean up
echo "Cleaning up..."
apt-get clean
apt-get autoclean

# Final dpkg cleanup
echo "Final cleanup of package database..."
dpkg --configure -a 2>/dev/null || true
apt-get install -f -y 2>/dev/null || true

echo ""
echo -e "${GREEN}======================================"
echo "  UNINSTALL COMPLETE!"
echo -e "======================================${NC}"
echo ""
echo "The system has been reset to a clean Debian state."
echo ""
echo "Remaining items to check manually (if needed):"
echo "  - DNS records (MX, A, SPF, DKIM, DMARC)"
echo "  - Firewall rules on hosting provider"
echo "  - Backup any data you still need"
echo ""
echo "You can now run the Ansible playbook again."
echo ""
echo -e "${YELLOW}Reboot recommended:${NC} sudo reboot"
echo ""
