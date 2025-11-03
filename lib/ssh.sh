#!/bin/bash
# ssh.sh - SSH security hardening

setup_ssh() {
    component_start "ssh"

    local sshd_config="/etc/ssh/sshd_config"

    if [[ ! -f "$sshd_config" ]]; then
        log_warning "SSH config file not found: $sshd_config"
        log_warning "Skipping SSH hardening (likely test environment)"
        component_success "ssh"
        return 0
    fi

    log_info "Hardening SSH configuration"

    # Disable password authentication
    if ! file_contains "$sshd_config" "PasswordAuthentication no"; then
        log_info "Disabling password authentication"
        update_config "$sshd_config" "PasswordAuthentication" "PasswordAuthentication no"
    else
        log_info "Password authentication already disabled"
    fi

    # Disable challenge-response authentication
    if ! file_contains "$sshd_config" "ChallengeResponseAuthentication no"; then
        log_info "Disabling challenge-response authentication"
        update_config "$sshd_config" "ChallengeResponseAuthentication" "ChallengeResponseAuthentication no"
    else
        log_info "Challenge-response authentication already disabled"
    fi

    # Disable keyboard-interactive authentication
    if ! file_contains "$sshd_config" "KbdInteractiveAuthentication no"; then
        log_info "Disabling keyboard-interactive authentication"
        update_config "$sshd_config" "KbdInteractiveAuthentication" "KbdInteractiveAuthentication no"
    else
        log_info "Keyboard-interactive authentication already disabled"
    fi

    # Enable public key authentication (ensure it's enabled)
    if ! file_contains "$sshd_config" "PubkeyAuthentication yes"; then
        log_info "Enabling public key authentication"
        update_config "$sshd_config" "PubkeyAuthentication" "PubkeyAuthentication yes"
    else
        log_info "Public key authentication already enabled"
    fi

    # Disable root login via password (but allow with keys)
    if ! file_contains "$sshd_config" "PermitRootLogin prohibit-password"; then
        log_info "Setting PermitRootLogin to prohibit-password"
        update_config "$sshd_config" "PermitRootLogin" "PermitRootLogin prohibit-password"
    else
        log_info "Root login already restricted to keys only"
    fi

    # Restart SSH service to apply changes
    log_info "Restarting SSH service"
    # Try both sshd and ssh service names (varies by distro)
    if sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh 2>/dev/null; then
        log_info "SSH service restarted successfully"
    else
        log_warning "Failed to restart SSH service - changes may not be applied"
    fi

    # Verify SSH service is running (check both possible names)
    if sudo systemctl is-active --quiet sshd 2>/dev/null || sudo systemctl is-active --quiet ssh 2>/dev/null; then
        log_info "SSH service is active and running"
    else
        component_fail "ssh" "SSH service is not running after restart"
        return 1
    fi

    component_success "ssh"
    return 0
}
