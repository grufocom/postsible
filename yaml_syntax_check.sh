#!/bin/bash
# YAML Syntax Checker für Postsible

set -e

echo "=================================="
echo "Postsible YAML Syntax Checker"
echo "=================================="
echo ""

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

check_yaml_file() {
    local file=$1
    echo -n "Checking $file ... "
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}SKIPPED (not found)${NC}"
        return
    fi
    
    # Check with Python yamllint if available
    if command -v yamllint &> /dev/null; then
        if yamllint -d relaxed "$file" &> /dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}ERROR${NC}"
            yamllint -d relaxed "$file"
            ERRORS=$((ERRORS + 1))
        fi
    # Fallback to ansible-playbook --syntax-check
    elif [[ "$file" == *.yml ]] && [[ "$file" == playbooks/* ]]; then
        if ansible-playbook --syntax-check "$file" &> /dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}ERROR${NC}"
            ansible-playbook --syntax-check "$file"
            ERRORS=$((ERRORS + 1))
        fi
    # Basic YAML validation with Python
    else
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" &> /dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}ERROR${NC}"
            python3 -c "import yaml; yaml.safe_load(open('$file'))"
            ERRORS=$((ERRORS + 1))
        fi
    fi
}

echo "Checking playbooks..."
check_yaml_file "playbooks/site.yml"
check_yaml_file "playbooks/maintenance.yml"

echo ""
echo "Checking inventory..."
check_yaml_file "inventory/hosts.yml"
check_yaml_file "inventory/group_vars/mailservers/vars.yml"
check_yaml_file "inventory/group_vars/mailservers/vault.yml.example"

echo ""
echo "Checking roles..."
for role in common ufw mariadb postfix dovecot rspamd nginx snappymail certbot fail2ban eset_icap; do
    echo ""
    echo "Role: $role"
    check_yaml_file "roles/$role/tasks/main.yml"
    check_yaml_file "roles/$role/handlers/main.yml"
    check_yaml_file "roles/$role/defaults/main.yml"
    check_yaml_file "roles/$role/vars/main.yml"
done

echo ""
echo "=================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All YAML files are valid!${NC}"
    exit 0
else
    echo -e "${RED}Found $ERRORS error(s)!${NC}"
    exit 1
fi
