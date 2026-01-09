# Postsible - Ansible Mailserver

Ein vollständiges Ansible Playbook zur automatisierten Installation eines produktionsreifen Mailservers auf Debian 13.

---

## 📧 Features

- **📬 Postfix** - SMTP Server mit virtuellen Domains
- **📭 Dovecot** - IMAP/POP3 mit Sieve-Support
- **🛡️ Rspamd** - Spam-Filter mit Bayes-Learning
- **🔐 DKIM/DMARC/SPF** - Email-Authentifizierung (CRITICAL!)
- **🌐 SnappyMail** - Modernes Webmail-Interface
- **🔒 Let's Encrypt** - Automatische SSL-Zertifikate
- **🔥 UFW** - Firewall-Konfiguration
- **🚫 Fail2ban** - Brute-Force-Schutz (6 Jails inkl. SnappyMail)
- **💾 MariaDB** - Virtuelle User & Domains
- **🦠 ESET ICAP** - Virenscanner (optional)
- **🔐 Security Hardening** - Defense-in-Depth Approach

---

## 🚀 Schnellstart

### 1. Interaktiver Setup (empfohlen)

```bash
# Repository klonen
git clone https://github.com/grufocom/postsible.git
cd postsible

# Interaktives Setup starten
./setup.sh --interactive
```

Das Script fragt alle wichtigen Informationen ab:
- Remote oder lokales Deployment?
- Server IP-Adresse
- Domain (z.B. `example.com`)
- Mail-Server Hostname (z.B. `mail.example.com`)
- Admin Email-Adresse

### 2. Quick-Setup mit Parametern

```bash
# Remote-Deployment
./setup.sh --remote 192.168.1.100 \
           --domain example.com \
           --hostname mail.example.com \
           --admin-email admin@example.com

# Lokales Deployment
./setup.sh --domain example.com \
           --hostname mail.example.com
```

### 3. Vault-Datei erstellen und verschlüsseln

```bash
# Template kopieren
cp inventory/group_vars/mailservers/vault.yml.example \
   inventory/group_vars/mailservers/vault.yml

# Passwörter im vault.yml anpassen (alle CHANGE_ME ersetzen)
nano inventory/group_vars/mailservers/vault.yml

# Vault verschlüsseln
ansible-vault encrypt inventory/group_vars/mailservers/vault.yml
```

### 4. DNS-Records konfigurieren

**Vor dem Deployment** müssen folgende DNS-Records gesetzt werden:

```dns
# MX Record
example.com.           IN MX   10 mail.example.com.

# A Record (Server IP)
mail.example.com.      IN A    192.168.1.100

# PTR Record (Reverse DNS - beim Hosting-Provider)
100.1.168.192.in-addr.arpa. IN PTR mail.example.com.

# SPF Records
example.com.           IN TXT  "v=spf1 mx -all"
mail.example.com.      IN TXT  "v=spf1 a -all"
```

**Nach dem Deployment** (DKIM-Keys werden generiert):

```dns
# DKIM Record (Key aus /root/dkim-dns-records.txt auf dem Server)
dkim._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=MIIBIj..."

# DMARC Record
_dmarc.example.com.    IN TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; adkim=s; aspf=s"
```

### 5. Deployment starten

```bash
# Komplettes Deployment
ansible-playbook playbooks/site.yml --ask-vault-pass

# Oder phasenweise
ansible-playbook playbooks/site.yml --tags phase1 --ask-vault-pass
ansible-playbook playbooks/site.yml --tags phase2 --ask-vault-pass
# etc.
```

---

## 📋 Systemanforderungen

- **OS:** Debian 13 (Trixie) - frische Installation
- **RAM:** Mindestens 2 GB
- **Disk:** 20 GB Festplattenspeicher
- **Zugriff:** Root-Zugriff via SSH
- **Netzwerk:** Öffentliche IPv4-Adresse
- **DNS:** Konfigurierte DNS-Records (siehe oben)

---

## 🏗️ Deployment-Phasen

### Phase 1: Basis-Infrastruktur
```bash
ansible-playbook playbooks/site.yml --tags phase1 --ask-vault-pass
```
- **common** - System-Updates & Basis-Pakete
- **ufw** - Firewall-Konfiguration
- **mariadb** - Datenbank für virtuelle User/Domains

### Phase 2: Mail-Core
```bash
ansible-playbook playbooks/site.yml --tags phase2 --ask-vault-pass
```
- **postfix** - SMTP Server mit intelligenter SSL-Erkennung
- **dovecot** - IMAP/POP3 mit Sieve-Support

### Phase 3: Spam-Filter
```bash
ansible-playbook playbooks/site.yml --tags phase3 --ask-vault-pass
```
- **rspamd** - Spam-Filter, DKIM-Signierung, Bayes-Learning
- **eset_icap** - Virenscanner (optional)

### Phase 4: Web & SSL
```bash
ansible-playbook playbooks/site.yml --tags phase4 --ask-vault-pass
```
- **nginx** - Webserver mit intelligenter SSL-Erkennung
- **certbot** - Let's Encrypt SSL-Zertifikate
- **snappymail** - Webmail-Interface

### Phase 5: Sicherheit
```bash
ansible-playbook playbooks/site.yml --tags phase5 --ask-vault-pass
```
- **fail2ban** - Brute-Force-Schutz (6 Jails)

---

## 🎯 Einzelne Roles ausführen

```bash
# Nur Postfix aktualisieren
ansible-playbook playbooks/site.yml --tags postfix --ask-vault-pass

# Nur SSL-Zertifikate erneuern
ansible-playbook playbooks/site.yml --tags certbot --ask-vault-pass

# Nur rspamd neu konfigurieren
ansible-playbook playbooks/site.yml --tags rspamd-configure --ask-vault-pass
```

---

## 🔐 Sicherheits-Features

### Intelligente SSL-Erkennung
Postfix und Nginx erkennen automatisch Let's Encrypt Zertifikate:
1. Bevorzugt: `/etc/letsencrypt/live/mail.example.com/`
2. Fallback: `/etc/letsencrypt/live/example.com/`
3. Fallback: Snakeoil (nur für Tests)

### Fail2ban Jails
- **SSH** - Schutz vor Brute-Force auf Port 22
- **Postfix SASL** - Auth-Failures beim Mail-Versand
- **Dovecot** - IMAP/POP3 Login-Failures
- **Nginx HTTP Auth** - Webserver-Authentifizierung
- **SnappyMail** - Webmail Login-Failures
- **Rspamd** - WebUI-Schutz (optional)

### DKIM/SPF/DMARC
- Automatische DKIM-Key-Generierung (2048-bit)
- ARC-Signierung aktiviert
- Strenge DMARC-Policy (configurable)

---

## 🛠️ Virtuelle Domains & User verwalten

### Domain hinzufügen
```sql
mysql -u root -p mailserver
INSERT INTO virtual_domains (name) VALUES ('neudomain.com');
```

### User hinzufügen
```bash
# Passwort hashen
doveadm pw -s SHA512-CRYPT

# User in DB eintragen
mysql -u root -p mailserver
INSERT INTO virtual_users (domain_id, email, password)
VALUES (
  (SELECT id FROM virtual_domains WHERE name='example.com'),
  'user@example.com',
  '{SHA512-CRYPT}DEIN_GEHASHTES_PASSWORT'
);
```

### Alias hinzufügen
```sql
INSERT INTO virtual_aliases (domain_id, source, destination)
VALUES (
  (SELECT id FROM virtual_domains WHERE name='example.com'),
  'alias@example.com',
  'user@example.com'
);
```

---

## 🌐 Zugriffsdaten

Nach erfolgreichem Deployment:

### Webmail
- **URL:** `https://webmail.example.com` oder `https://mail.example.com/wm/`
- **Login:** Vollständige E-Mail-Adresse + Passwort

### Rspamd WebUI
- **URL:** `https://mail.example.com/rspamd/`
- **Passwort:** Aus `vault_rspamd_webui_password`

### IMAP-Zugriff
- **Server:** mail.example.com
- **Port:** 993 (SSL/TLS)
- **Auth:** E-Mail-Adresse + Passwort

### SMTP-Versand
- **Server:** mail.example.com
- **Port:** 587 (STARTTLS) oder 465 (SSL/TLS)
- **Auth:** E-Mail-Adresse + Passwort

---

## 🔧 Wartung

### Logs prüfen
```bash
# Mail-Logs
tail -f /var/log/mail/mail.log

# Rspamd-Logs
tail -f /var/log/rspamd/rspamd.log

# Nginx-Logs
tail -f /var/log/nginx/access.log
```

### Service-Status
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

# Fail2ban
fail2ban-client status
fail2ban-client status postfix-sasl
```

### Spam-Learning
User können selbst trainieren:
1. Spam-Mails in den Ordner `.Spam/` verschieben
2. Fälschlich als Spam markierte Mails in `.Ham/` verschieben
3. Rspamd lernt automatisch via Cronjob (alle 30min + täglich 3:00 Uhr)

### SSL-Zertifikate erneuern
```bash
# Läuft automatisch via Certbot
# Manuell:
certbot renew
systemctl reload postfix dovecot nginx
```

---

## 🐛 Troubleshooting

### DKIM funktioniert nicht
```bash
# Check DKIM-Keys
ls -la /var/lib/rspamd/dkim/

# rspamd neu starten
systemctl restart rspamd

# Log beobachten
tail -f /var/log/rspamd/rspamd.log | grep -i dkim

# Test-Mail senden und prüfen
# Sollte zeigen: DKIM_SIGNED(0.00){example.com:s=dkim;}
```

### Mail wird als Spam markiert
```bash
# Checks durchführen
# 1. SPF-Check
dig TXT example.com +short
dig TXT mail.example.com +short

# 2. DKIM-Check
dig TXT dkim._domainkey.example.com +short

# 3. DMARC-Check
dig TXT _dmarc.example.com +short

# 4. Reverse DNS (PTR)
dig -x DEINE_SERVER_IP +short

# Online-Tests
# https://www.mail-tester.com/
# https://mxtoolbox.com/SuperTool.aspx
```

### Firewall-Probleme
```bash
# Status prüfen
ufw status verbose

# Port öffnen (falls nötig)
ufw allow 587/tcp comment "SMTP Submission"
```

---

## 📁 Projekt-Struktur

```
postsible/
├── inventory/
│   ├── hosts.yml                           # Server-Inventar
│   └── group_vars/
│       └── mailservers/
│           ├── vars.yml                    # Öffentliche Variablen
│           └── vault.yml                   # Verschlüsselte Secrets
├── roles/
│   ├── common/                             # System-Basis
│   ├── ufw/                                # Firewall
│   ├── mariadb/                            # Datenbank
│   ├── postfix/                            # SMTP
│   ├── dovecot/                            # IMAP/Sieve
│   ├── rspamd/                             # Spam-Filter + DKIM
│   ├── nginx/                              # Webserver
│   ├── certbot/                            # SSL
│   ├── snappymail/                         # Webmail
│   ├── fail2ban/                           # Brute-Force-Schutz
│   └── eset_icap/                          # Antivirus (optional)
├── playbooks/
│   ├── site.yml                            # Haupt-Playbook
│   └── maintenance.yml                     # Wartungs-Playbook
├── setup.sh                                # Intelligentes Setup-Script
├── ansible.cfg                             # Ansible-Konfiguration
└── README.md                               # Diese Datei
```

---

## 🔄 Updates & Backups

### System-Updates
```bash
ansible-playbook playbooks/maintenance.yml --tags update --ask-vault-pass
```

### Backup wichtiger Daten
```bash
# MariaDB
mysqldump -u root -p mailserver > mailserver-backup.sql

# Mailboxen
tar czf mailboxes-backup.tar.gz /srv/imap/

# Konfiguration
tar czf config-backup.tar.gz /etc/postfix /etc/dovecot /etc/rspamd /etc/nginx
```

---

## 🤝 Bekannte Probleme & Lösungen

### rspamd Neural Network Crashes
**Problem:** Neural Network-Modul verursacht Segmentation Faults  
**Lösung:** Neural Network ist standardmäßig deaktiviert (`rspamd_enable_neural: false`)  
**Bayes-Filter allein reicht für 95% der Spam-Erkennung aus**

### sign_headers verursacht DKIM-Crash
**Problem:** Custom `sign_headers` Liste führt zu rspamd-Absturz  
**Lösung:** Entfernt aus Template, rspamd nutzt vernünftige Defaults

---

## 📚 Weitere Dokumentation

- **Rspamd:** https://rspamd.com/doc/
- **Postfix:** http://www.postfix.org/documentation.html
- **Dovecot:** https://doc.dovecot.org/
- **SnappyMail:** https://snappymail.eu/
- **fail2ban:** https://github.com/fail2ban/fail2ban/wiki

---

## 📜 Lizenz

MIT License - siehe [LICENSE](LICENSE) Datei

---

## 🙏 Credits

Entwickelt als umfassende Mailserver-Lösung mit Fokus auf:
- **Sicherheit** (DKIM, SPF, DMARC, fail2ban, SSL)
- **Benutzerfreundlichkeit** (Interaktives Setup, automatische Config)
- **Wartbarkeit** (Ansible, modularer Aufbau, gute Dokumentation)
- **Produktionsreife** (Getestet, stabil, Best Practices)

---

## 💡 Support

Bei Problemen:
1. Logs prüfen (`/var/log/mail/`, `/var/log/rspamd/`)
2. Service-Status prüfen (`systemctl status postfix dovecot rspamd`)
3. GitHub Issues erstellen: https://github.com/grufocom/postsible/issues
4. Community-Forum konsultieren

---
