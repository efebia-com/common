#!/bin/bash
# base.sh - Core utilities for OVH provisioning system
# Provides logging, error handling, and common functions

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_NAME="${SCRIPT_NAME:-provisioning}"
LOG_FILE="${LOG_FILE:-/var/log/post-install.log}"
CURRENT_COMPONENT=""
FAILED_COMPONENTS=()
SUCCEEDED_COMPONENTS=()

# ============================================================================
# Logging Functions
# ============================================================================

# Initialize logging
init_logging() {
    # If running as non-root, use home directory
    if [[ $EUID -ne 0 ]]; then
        LOG_FILE="$HOME/post-install.log"
    fi

    # Ensure log file is writable
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "ERROR: Cannot write to log file: $LOG_FILE" >&2
        exit 1
    fi

    log_info "==================================================================="
    log_info "Starting $SCRIPT_NAME provisioning at $(date)"
    log_info "==================================================================="
}

# Log with timestamp and level
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local component_tag=""

    if [[ -n "$CURRENT_COMPONENT" ]]; then
        component_tag="[$CURRENT_COMPONENT]"
    fi

    echo "[$timestamp] [$level] $component_tag $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_warning() {
    log "WARNING" "$@"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        log "DEBUG" "$@"
    fi
}

# ============================================================================
# Component Management
# ============================================================================

# Start a component
component_start() {
    local component_name="$1"
    CURRENT_COMPONENT="$component_name"
    log_info "Starting component: $component_name"
}

# Mark component as successful
component_success() {
    local component_name="${1:-$CURRENT_COMPONENT}"
    SUCCEEDED_COMPONENTS+=("$component_name")
    log_success "Component completed: $component_name"
    CURRENT_COMPONENT=""
}

# Mark component as failed
component_fail() {
    local component_name="${1:-$CURRENT_COMPONENT}"
    local error_message="${2:-Unknown error}"
    FAILED_COMPONENTS+=("$component_name")
    log_error "Component failed: $component_name - $error_message"
    CURRENT_COMPONENT=""
}

# Report final status
report_status() {
    log_info "==================================================================="
    log_info "Provisioning Summary"
    log_info "==================================================================="

    if [[ ${#SUCCEEDED_COMPONENTS[@]} -gt 0 ]]; then
        log_success "Succeeded (${#SUCCEEDED_COMPONENTS[@]}):"
        for component in "${SUCCEEDED_COMPONENTS[@]}"; do
            log_success "  ✓ $component"
        done
    fi

    if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
        log_error "Failed (${#FAILED_COMPONENTS[@]}):"
        for component in "${FAILED_COMPONENTS[@]}"; do
            log_error "  ✗ $component"
        done
        log_error "Provisioning completed with errors. Check log: $LOG_FILE"
        return 1
    else
        log_success "All components completed successfully!"
        return 0
    fi
}

# ============================================================================
# Idempotency Checks
# ============================================================================

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if user exists
user_exists() {
    id "$1" >/dev/null 2>&1
}

# Check if group exists
group_exists() {
    getent group "$1" >/dev/null 2>&1
}

# Check if package is installed (apt)
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Check if file contains pattern
file_contains() {
    local file="$1"
    local pattern="$2"
    [[ -f "$file" ]] && grep -qF "$pattern" "$file"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Run command with error handling
run_safe() {
    local description="$1"
    shift
    local cmd=("$@")

    log_debug "Running: ${cmd[*]}"

    if "${cmd[@]}" >> "$LOG_FILE" 2>&1; then
        log_debug "$description - Success"
        return 0
    else
        log_error "$description - Failed (exit code: $?)"
        return 1
    fi
}

# Download file safely
download_file() {
    local url="$1"
    local output="$2"

    if curl -fsSL "$url" -o "$output"; then
        log_debug "Downloaded: $url -> $output"
        return 0
    else
        log_error "Failed to download: $url"
        return 1
    fi
}

# Update config file safely (idempotent)
update_config() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"
    local backup="${file}.bak"

    if [[ ! -f "$file" ]]; then
        log_error "Config file not found: $file"
        return 1
    fi

    # Create backup
    cp "$file" "$backup"

    # If pattern exists, replace it
    if grep -qF "$pattern" "$file"; then
        sed -i "s|^.*${pattern}.*|${replacement}|" "$file"
        log_debug "Updated existing: $pattern -> $replacement in $file"
    else
        # If pattern doesn't exist, append
        echo "$replacement" >> "$file"
        log_debug "Appended: $replacement to $file"
    fi

    return 0
}

# Add line to file if not present (idempotent)
add_line_if_missing() {
    local file="$1"
    local line="$2"

    if [[ ! -f "$file" ]]; then
        echo "$line" > "$file"
        log_debug "Created file with: $file"
        return 0
    fi

    if ! grep -qF "$line" "$file"; then
        echo "$line" >> "$file"
        log_debug "Added line to: $file"
    else
        log_debug "Line already present in: $file"
    fi

    return 0
}

# ============================================================================
# Initialization
# ============================================================================

# Auto-initialize logging when sourced
init_logging
