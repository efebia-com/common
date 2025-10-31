#!/bin/bash
# post-install.sh - Unified OVH server provisioning entry point
# Usage: curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh?profile=NAME' | bash
# Available profiles: backend, database, general

set -euo pipefail

# Configuration
# Detect if running from local directory (for testing) or need to download from GitHub
if [[ -f "./lib/base.sh" ]]; then
    # Running from local repository (test mode or manual execution)
    REPO_BASE_URL="."
    USE_LOCAL=true
else
    # Running from curl | bash (production mode)
    REPO_BASE_URL="https://raw.githubusercontent.com/efebia-com/common/master"
    USE_LOCAL=false
fi

# Extract profile parameter from query string
# When curl downloads a URL with ?param=value, bash receives it as $0 or via parsing
# We need to extract it from the command line or stdin
PROFILE_NAME=""

# Method 1: Try to extract from $0 (script name) if it contains the query string
if [[ "$0" =~ profile=([a-zA-Z0-9_-]+) ]]; then
    PROFILE_NAME="${BASH_REMATCH[1]}"
fi

# Method 2: Check if passed as first argument
if [[ -z "$PROFILE_NAME" ]] && [[ $# -gt 0 ]]; then
    PROFILE_NAME="$1"
fi

# Method 3: Check environment variable (for manual runs)
if [[ -z "$PROFILE_NAME" ]] && [[ -n "${PROFILE:-}" ]]; then
    PROFILE_NAME="$PROFILE"
fi

# Require profile parameter
if [[ -z "$PROFILE_NAME" ]]; then
    cat >&2 <<'EOF'
ERROR: Profile parameter is required.

Usage:
  curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh?profile=NAME' | bash

Available profiles:
  - backend   : Application servers (Docker + Cloudflared)
  - database  : Database servers (Docker only)
  - general   : General purpose servers (minimal setup)

Examples:
  curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh?profile=backend' | bash
  curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh?profile=database' | bash
  curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh?profile=general' | bash

For manual runs:
  PROFILE=backend bash post-install.sh
  bash post-install.sh backend

EOF
    exit 1
fi

# Load base utilities (local or download)
if [[ "$USE_LOCAL" == "true" ]]; then
    echo "Using local files..."
    source "${REPO_BASE_URL}/lib/base.sh"
else
    echo "Downloading base utilities..."
    if ! curl -fsSL "${REPO_BASE_URL}/lib/base.sh" -o /tmp/base.sh; then
        echo "ERROR: Failed to download base utilities" >&2
        exit 1
    fi
    source /tmp/base.sh
fi

# Set script name for logging
export SCRIPT_NAME="${PROFILE_NAME}-provisioning"

log_info "Starting server provisioning"
log_info "Repository: ${REPO_BASE_URL}"
log_info "Profile: ${PROFILE_NAME}"

# Load profile (local or download)
if [[ "$USE_LOCAL" == "true" ]]; then
    log_info "Loading local profile: ${PROFILE_NAME}"
    if [[ ! -f "${REPO_BASE_URL}/profiles/${PROFILE_NAME}.profile" ]]; then
        log_error "Profile not found: ${PROFILE_NAME}"
        log_error "Available profiles: backend, database, general"
        exit 1
    fi
    source "${REPO_BASE_URL}/profiles/${PROFILE_NAME}.profile"
else
    log_info "Downloading profile: ${PROFILE_NAME}"
    if ! download_file "${REPO_BASE_URL}/profiles/${PROFILE_NAME}.profile" "/tmp/${PROFILE_NAME}.profile"; then
        log_error "Failed to download profile: ${PROFILE_NAME}"
        log_error "Available profiles: backend, database, general"
        exit 1
    fi
    source "/tmp/${PROFILE_NAME}.profile"
fi

log_info "Loaded profile: ${SERVER_TYPE}"
log_info "Components to install: ${COMPONENTS[*]}"

# Load component modules (local or download)
if [[ "$USE_LOCAL" == "true" ]]; then
    log_info "Loading local component modules..."
    for component in "${COMPONENTS[@]}"; do
        log_info "Loading component: ${component}"
        if [[ ! -f "${REPO_BASE_URL}/lib/${component}.sh" ]]; then
            log_error "Component not found: ${component}"
            exit 1
        fi
        source "${REPO_BASE_URL}/lib/${component}.sh"
    done
else
    log_info "Downloading component modules..."
    for component in "${COMPONENTS[@]}"; do
        log_info "Downloading component: ${component}"
        if ! download_file "${REPO_BASE_URL}/lib/${component}.sh" "/tmp/${component}.sh"; then
            log_error "Failed to download component: ${component}"
            exit 1
        fi
        source "/tmp/${component}.sh"
    done
fi

# Execute components in order
log_info "==================================================================="
log_info "Executing components"
log_info "==================================================================="

for component in "${COMPONENTS[@]}"; do
    # Call setup function for each component (e.g., setup_system, setup_docker)
    setup_function="setup_${component}"

    if declare -f "$setup_function" > /dev/null; then
        log_info "Executing: ${setup_function}"
        if ! $setup_function; then
            log_error "Component failed: ${component}"
            # Continue with other components even if one fails
        fi
    else
        log_error "Setup function not found: ${setup_function}"
        component_fail "$component" "Setup function not found"
    fi
done

# Report final status
report_status
exit_code=$?

# Cleanup
rm -f /tmp/base.sh /tmp/${PROFILE_NAME}.profile
for component in "${COMPONENTS[@]}"; do
    rm -f "/tmp/${component}.sh"
done

exit $exit_code
