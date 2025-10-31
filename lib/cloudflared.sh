#!/bin/bash
# cloudflared.sh - Cloudflare Tunnel daemon installation

setup_cloudflared() {
    component_start "cloudflared"

    # Check if cloudflared is already installed
    if command_exists cloudflared; then
        local cf_version=$(cloudflared --version 2>/dev/null || echo "unknown")
        log_info "Cloudflared already installed: $cf_version"
        component_success "cloudflared"
        return 0
    fi

    log_info "Installing Cloudflared"

    # Add Cloudflare GPG key
    log_info "Adding Cloudflare GPG key"
    if ! curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null; then
        component_fail "cloudflared" "Failed to add Cloudflare GPG key"
        return 1
    fi

    # Add Cloudflare repository
    log_info "Adding Cloudflare repository"
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/cloudflared.list > /dev/null

    # Update package lists
    if ! run_safe "Update apt after adding Cloudflare repo" apt-get update; then
        component_fail "cloudflared" "Failed to update package lists"
        return 1
    fi

    # Install cloudflared
    if ! run_safe "Install cloudflared" apt-get install -y cloudflared; then
        component_fail "cloudflared" "Failed to install cloudflared"
        return 1
    fi

    # Verify installation
    if ! command_exists cloudflared; then
        component_fail "cloudflared" "Cloudflared command not found after installation"
        return 1
    fi

    local cf_version=$(cloudflared --version)
    log_info "Cloudflared installed successfully: $cf_version"

    component_success "cloudflared"
    return 0
}
