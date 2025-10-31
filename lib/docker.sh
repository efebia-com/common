#!/bin/bash
# docker.sh - Docker CE installation with compose and buildx plugins

setup_docker() {
    component_start "docker"

    # Skip Docker installation in test environments
    if [[ "${SKIP_DOCKER:-0}" == "1" ]]; then
        log_info "Skipping Docker installation (SKIP_DOCKER=1)"
        component_success "docker"
        return 0
    fi

    # Check if Docker is already installed
    if command_exists docker; then
        local docker_version=$(docker --version 2>/dev/null || echo "unknown")
        log_info "Docker already installed: $docker_version"
        component_success "docker"
        return 0
    fi

    log_info "Installing Docker CE"

    # Install prerequisites
    local prereqs=(ca-certificates curl gnupg)
    if ! run_safe "Install Docker prerequisites" apt-get install -y "${prereqs[@]}"; then
        component_fail "docker" "Failed to install prerequisites"
        return 1
    fi

    # Add Docker's official GPG key
    log_info "Adding Docker GPG key"
    install -m 0755 -d /etc/apt/keyrings
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
        component_fail "docker" "Failed to download Docker GPG key"
        return 1
    fi
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    log_info "Adding Docker repository"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package index
    if ! run_safe "Update apt after adding Docker repo" apt-get update; then
        component_fail "docker" "Failed to update package lists"
        return 1
    fi

    # Install Docker packages
    local docker_packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )

    log_info "Installing Docker packages: ${docker_packages[*]}"
    if ! run_safe "Install Docker packages" apt-get install -y "${docker_packages[@]}"; then
        component_fail "docker" "Failed to install Docker packages"
        return 1
    fi

    # Verify installation
    if ! command_exists docker; then
        component_fail "docker" "Docker command not found after installation"
        return 1
    fi

    # Enable and start Docker service
    log_info "Enabling Docker service"
    if ! run_safe "Enable Docker service" systemctl enable docker; then
        log_warning "Failed to enable Docker service"
    fi

    if ! run_safe "Start Docker service" systemctl start docker; then
        log_warning "Failed to start Docker service"
    fi

    # Verify Docker is working
    local docker_version=$(docker --version)
    log_info "Docker installed successfully: $docker_version"

    component_success "docker"
    return 0
}
