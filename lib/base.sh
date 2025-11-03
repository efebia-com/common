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
# Pre-flight Checks
# ============================================================================

# Check system prerequisites before starting
preflight_checks() {
    log_info "Running pre-flight checks..."
    local checks_passed=true

    # Check 1: Operating System
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            log_error "Pre-flight: This script is designed for Ubuntu (found: $ID)"
            checks_passed=false
        else
            log_info "Pre-flight: OS check passed (Ubuntu $VERSION_ID)"
        fi
    else
        log_warning "Pre-flight: Cannot determine OS version"
    fi

    # Check 2: Sudo access (passwordless)
    if sudo -n true 2>/dev/null; then
        log_info "Pre-flight: Sudo access confirmed (passwordless)"
    else
        log_error "Pre-flight: Sudo access required. Ensure user has passwordless sudo configured."
        log_error "Pre-flight: Add to /etc/sudoers: $(whoami) ALL=(ALL) NOPASSWD:ALL"
        checks_passed=false
    fi

    # Check 3: Internet connectivity
    if curl -fsSL --connect-timeout 5 https://raw.githubusercontent.com > /dev/null 2>&1; then
        log_info "Pre-flight: Internet connectivity confirmed"
    else
        log_error "Pre-flight: No internet connectivity. Cannot download components."
        checks_passed=false
    fi

    # Check 4: Disk space (require at least 5GB free)
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_gb -ge 5 ]]; then
        log_info "Pre-flight: Sufficient disk space (${available_gb}GB available)"
    else
        log_warning "Pre-flight: Low disk space (${available_gb}GB available, 5GB+ recommended)"
    fi

    # Check 5: Required commands
    local required_cmds=("curl" "wget" "bash" "apt-get")
    for cmd in "${required_cmds[@]}"; do
        if command_exists "$cmd"; then
            log_debug "Pre-flight: Command found: $cmd"
        else
            log_error "Pre-flight: Required command not found: $cmd"
            checks_passed=false
        fi
    done

    if [[ "$checks_passed" == "false" ]]; then
        log_error "Pre-flight checks failed. Please resolve the issues above and try again."
        return 1
    fi

    log_success "Pre-flight checks passed!"
    return 0
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

    # Create backup (with sudo if needed for system files)
    if [[ -w "$file" ]]; then
        cp "$file" "$backup"
    else
        sudo cp "$file" "$backup"
    fi

    # If pattern exists, replace it
    if grep -qF "$pattern" "$file"; then
        if [[ -w "$file" ]]; then
            sed -i "s|^.*${pattern}.*|${replacement}|" "$file"
        else
            sudo sed -i "s|^.*${pattern}.*|${replacement}|" "$file"
        fi
        log_debug "Updated existing: $pattern -> $replacement in $file"
    else
        # If pattern doesn't exist, append
        if [[ -w "$file" ]]; then
            echo "$replacement" >> "$file"
        else
            echo "$replacement" | sudo tee -a "$file" > /dev/null
        fi
        log_debug "Appended: $replacement to $file"
    fi

    return 0
}

# Add line to file if not present (idempotent)
add_line_if_missing() {
    local file="$1"
    local line="$2"

    if [[ ! -f "$file" ]]; then
        # Create file (with sudo if in a protected directory)
        local dir=$(dirname "$file")
        if [[ -w "$dir" ]]; then
            echo "$line" > "$file"
        else
            echo "$line" | sudo tee "$file" > /dev/null
        fi
        log_debug "Created file with: $file"
        return 0
    fi

    if ! grep -qF "$line" "$file"; then
        # Add line (with sudo if needed)
        if [[ -w "$file" ]]; then
            echo "$line" >> "$file"
        else
            echo "$line" | sudo tee -a "$file" > /dev/null
        fi
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
