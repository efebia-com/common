#!/bin/bash
# Validation script for OVH provisioning
# Checks that all expected components were installed correctly

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROFILE="${1:-general}"
FAILURES=0

log_check() {
    echo -n "  Checking: $1... "
}

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}"
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC} - $1"
    FAILURES=$((FAILURES + 1))
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC} - $1"
}

echo "=========================================="
echo "Validating $PROFILE profile installation"
echo "=========================================="

# Check log file exists
log_check "Provisioning log file"
if [[ -f /var/log/post-install.log ]]; then
    log_pass
else
    log_fail "Log file not found: /var/log/post-install.log"
fi

# Check users
echo -e "\nUser Accounts:"

log_check "devops user"
if id devops >/dev/null 2>&1; then
    log_pass
else
    log_fail "User 'devops' not found"
fi

log_check "runner user"
if id runner >/dev/null 2>&1; then
    log_pass
else
    log_fail "User 'runner' not found"
fi

log_check "gh-actions user"
if id gh-actions >/dev/null 2>&1; then
    log_pass
else
    log_fail "User 'gh-actions' not found"
fi

# Check groups
echo -e "\nGroups:"

log_check "apps group"
if getent group apps >/dev/null 2>&1; then
    log_pass
else
    log_fail "Group 'apps' not found"
fi

if [[ "${SKIP_DOCKER:-0}" == "1" ]]; then
    log_check "docker group"
    log_skip "Skipped in test environment (SKIP_DOCKER=1)"
else
    log_check "docker group"
    if getent group docker >/dev/null 2>&1; then
        log_pass
    else
        log_fail "Group 'docker' not found"
    fi
fi

# Check group memberships
log_check "devops in apps group"
if groups devops 2>/dev/null | grep -q apps; then
    log_pass
else
    log_fail "User 'devops' not in 'apps' group"
fi

if [[ "${SKIP_DOCKER:-0}" == "1" ]]; then
    log_check "devops in docker group"
    log_skip "Skipped in test environment (SKIP_DOCKER=1)"
else
    log_check "devops in docker group"
    if groups devops 2>/dev/null | grep -q docker; then
        log_pass
    else
        log_fail "User 'devops' not in 'docker' group"
    fi
fi

# Check directories
echo -e "\nDirectories:"

log_check "/opt/apps directory"
if [[ -d /opt/apps ]]; then
    log_pass
else
    log_fail "Directory /opt/apps not found"
fi

log_check "/opt/apps permissions"
if [[ -d /opt/apps ]]; then
    perms=$(stat -c "%a" /opt/apps)
    if [[ "$perms" == "2775" ]]; then
        log_pass
    else
        log_fail "Wrong permissions: $perms (expected 2775)"
    fi
else
    log_skip "Directory doesn't exist"
fi

# Check Docker installation
echo -e "\nDocker:"

if [[ "${SKIP_DOCKER:-0}" == "1" ]]; then
    log_check "Docker installation"
    log_skip "Skipped in test environment (SKIP_DOCKER=1)"
else
    log_check "Docker installed"
    if command -v docker >/dev/null 2>&1; then
        log_pass
        docker_version=$(docker --version)
        echo "      Version: $docker_version"
    else
        log_fail "Docker command not found"
    fi

    log_check "Docker Compose plugin"
    if docker compose version >/dev/null 2>&1; then
        log_pass
    else
        log_fail "Docker Compose plugin not found"
    fi

    log_check "Docker Buildx plugin"
    if docker buildx version >/dev/null 2>&1; then
        log_pass
    else
        log_fail "Docker Buildx plugin not found"
    fi

    log_check "Docker service running"
    if systemctl is-active --quiet docker 2>/dev/null; then
        log_pass
    else
        log_fail "Docker service not running"
    fi
fi

# Check SSH configuration
echo -e "\nSSH Configuration:"

SSH_CONFIG_EXISTS=false
log_check "SSH config file"
if [[ -f /etc/ssh/sshd_config ]]; then
    log_pass
    SSH_CONFIG_EXISTS=true
else
    log_skip "SSH config file not found (test environment)"
fi

if [[ "$SSH_CONFIG_EXISTS" == "true" ]]; then
    log_check "Password authentication disabled"
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        log_pass
    else
        log_fail "Password authentication not disabled"
    fi

    log_check "Public key authentication enabled"
    if grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        log_pass
    else
        log_fail "Public key authentication not enabled"
    fi
else
    log_check "Password authentication disabled"
    log_skip "SSH not configured (test environment)"

    log_check "Public key authentication enabled"
    log_skip "SSH not configured (test environment)"
fi

# Check Ghostty terminal support
echo -e "\nTerminal Support:"

log_check "Ghostty terminfo"
if infocmp xterm-ghostty >/dev/null 2>&1; then
    log_pass
else
    log_fail "Ghostty terminfo not installed"
fi

log_check "TERM fix in /etc/skel/.bashrc"
if [[ -f /etc/skel/.bashrc ]] && grep -q "xterm-ghostty" /etc/skel/.bashrc; then
    log_pass
else
    log_fail "TERM fix not found in /etc/skel/.bashrc"
fi

# Profile-specific checks
echo -e "\nProfile-Specific ($PROFILE):"

case "$PROFILE" in
    backend)
        log_check "Cloudflared installed"
        if command -v cloudflared >/dev/null 2>&1; then
            log_pass
            cf_version=$(cloudflared --version | head -1)
            echo "      Version: $cf_version"
        else
            log_fail "Cloudflared not found"
        fi

        log_check "Node.js NOT installed (as per config)"
        if command -v node >/dev/null 2>&1; then
            log_fail "Node.js found but should not be installed for backend"
        else
            log_pass
        fi
        ;;

    database)
        log_check "Cloudflared NOT installed"
        if command -v cloudflared >/dev/null 2>&1; then
            log_fail "Cloudflared found but should not be installed for database"
        else
            log_pass
        fi

        log_check "Node.js NOT installed"
        if command -v node >/dev/null 2>&1; then
            log_fail "Node.js found but should not be installed for database"
        else
            log_pass
        fi
        ;;

    general)
        log_check "Cloudflared NOT installed"
        if command -v cloudflared >/dev/null 2>&1; then
            log_fail "Cloudflared found but should not be installed for general"
        else
            log_pass
        fi

        log_check "Node.js NOT installed"
        if command -v node >/dev/null 2>&1; then
            log_fail "Node.js found but should not be installed for general"
        else
            log_pass
        fi
        ;;
esac

# Check essential packages
echo -e "\nEssential Packages:"

for pkg in curl wget git vim htop; do
    log_check "$pkg installed"
    if command -v "$pkg" >/dev/null 2>&1; then
        log_pass
    else
        log_fail "$pkg not found"
    fi
done

# Summary
echo -e "\n=========================================="
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILURES validation check(s) failed${NC}"
    exit 1
fi
