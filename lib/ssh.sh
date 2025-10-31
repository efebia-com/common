#!/bin/bash
# ssh.sh - SSH security hardening

setup_ssh() {
    component_start "ssh"

    local sshd_config="/etc/ssh/sshd_config"

    if [[ ! -f "$sshd_config" ]]; then
        component_fail "ssh" "SSH config file not found: $sshd_config"
        return 1
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
    if ! run_safe "Restart SSH service" systemctl restart sshd; then
        log_warning "Failed to restart SSH service - changes may not be applied"
    fi

    # Verify SSH service is running
    if systemctl is-active --quiet sshd; then
        log_info "SSH service is active and running"
    else
        component_fail "ssh" "SSH service is not running after restart"
        return 1
    fi

    component_success "ssh"
    return 0
}
