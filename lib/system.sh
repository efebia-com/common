#!/bin/bash
# system.sh - System updates and basic package installation

setup_system() {
    component_start "system"

    # Update package lists
    if ! run_safe "Update apt package lists" apt-get update; then
        component_fail "system" "Failed to update package lists"
        return 1
    fi

    # Upgrade existing packages
    if ! run_safe "Upgrade existing packages" apt-get upgrade -y; then
        component_fail "system" "Failed to upgrade packages"
        return 1
    fi

    # Install essential packages
    local packages=(
        curl
        wget
        git
        vim
        htop
        build-essential
        ca-certificates
        gnupg
        lsb-release
    )

    log_info "Installing essential packages: ${packages[*]}"

    if ! run_safe "Install essential packages" apt-get install -y "${packages[@]}"; then
        component_fail "system" "Failed to install essential packages"
        return 1
    fi

    component_success "system"
    return 0
}
