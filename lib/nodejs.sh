#!/bin/bash
# nodejs.sh - Node.js installation via NVM

# Configuration
NODE_VERSION="${NODE_VERSION:-24}"
NVM_VERSION="${NVM_VERSION:-v0.40.1}"

setup_nodejs() {
    component_start "nodejs"

    # Check if node is already installed globally
    if command_exists node; then
        local node_version=$(node --version 2>/dev/null || echo "unknown")
        log_info "Node.js already installed: $node_version"
        component_success "nodejs"
        return 0
    fi

    log_info "Installing NVM and Node.js v${NODE_VERSION}"

    # Download and install NVM
    local nvm_install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
    local nvm_install_script="/tmp/nvm-install.sh"

    if ! download_file "$nvm_install_url" "$nvm_install_script"; then
        component_fail "nodejs" "Failed to download NVM installer"
        return 1
    fi

    # Run NVM installer
    if ! bash "$nvm_install_script" >> "$LOG_FILE" 2>&1; then
        component_fail "nodejs" "Failed to install NVM"
        rm -f "$nvm_install_script"
        return 1
    fi

    rm -f "$nvm_install_script"

    # Load NVM for current session
    export NVM_DIR="$HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        . "$NVM_DIR/nvm.sh"
    else
        component_fail "nodejs" "NVM installation succeeded but nvm.sh not found"
        return 1
    fi

    # Install Node.js
    log_info "Installing Node.js v${NODE_VERSION}"
    if ! nvm install "$NODE_VERSION" >> "$LOG_FILE" 2>&1; then
        component_fail "nodejs" "Failed to install Node.js v${NODE_VERSION}"
        return 1
    fi

    # Set default Node version
    if ! nvm alias default "$NODE_VERSION" >> "$LOG_FILE" 2>&1; then
        log_warning "Failed to set default Node.js version"
    fi

    # Verify installation
    if ! command_exists node; then
        component_fail "nodejs" "Node.js command not found after installation"
        return 1
    fi

    local installed_node_version=$(node --version)
    local installed_npm_version=$(npm --version)
    log_info "Node.js installed: $installed_node_version, npm: $installed_npm_version"

    component_success "nodejs"
    return 0
}
