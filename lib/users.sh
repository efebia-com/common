#!/bin/bash
# users.sh - User account and group management

# Configuration - can be overridden by profiles
USER_DEVOPS="${USER_DEVOPS:-devops}"
USER_RUNNER="${USER_RUNNER:-runner}"
USER_GHACTIONS="${USER_GHACTIONS:-gh-actions}"
APPS_DIR="${APPS_DIR:-/opt/apps}"

# SSH keys for devops user (can be array or single key for backward compatibility)
if [[ -z "${DEVOPS_SSH_KEYS:-}" ]]; then
    # Backward compatibility: single key
    DEVOPS_SSH_KEYS=("${DEVOPS_SSH_KEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKwF12bPWwBPKF29ERFtj7H4a3yeYNj5PrVsvqFEG4J8 devops@efebia.com}")
fi

setup_users() {
    component_start "users"

    # Create 'apps' group if it doesn't exist
    if ! group_exists "apps"; then
        log_info "Creating 'apps' group"
        if ! run_safe "Create apps group" sudo groupadd apps; then
            component_fail "users" "Failed to create 'apps' group"
            return 1
        fi
    else
        log_info "Group 'apps' already exists, skipping"
    fi

    # Create devops user (human operator)
    if ! user_exists "$USER_DEVOPS"; then
        log_info "Creating '$USER_DEVOPS' user"
        # Add to docker group only if it exists
        local groups="apps"
        if group_exists "docker"; then
            groups="apps,docker"
        fi
        if ! run_safe "Create devops user" sudo useradd -m -s /bin/bash -G "$groups" "$USER_DEVOPS"; then
            component_fail "users" "Failed to create '$USER_DEVOPS' user"
            return 1
        fi
    else
        log_info "User '$USER_DEVOPS' already exists"
    fi

    # ALWAYS update SSH keys for devops (even if user already exists)
    # This allows adding/removing team members by re-running the script
    log_info "Updating SSH keys for '$USER_DEVOPS'"
    local ssh_dir="/home/$USER_DEVOPS/.ssh"
    sudo mkdir -p "$ssh_dir"

    # Brutally replace all keys (delete old, write new)
    sudo rm -f "$ssh_dir/authorized_keys"
    for key in "${DEVOPS_SSH_KEYS[@]}"; do
        echo "$key" | sudo tee -a "$ssh_dir/authorized_keys" > /dev/null
    done

    sudo chmod 700 "$ssh_dir"
    sudo chmod 600 "$ssh_dir/authorized_keys"
    sudo chown -R "$USER_DEVOPS:$USER_DEVOPS" "$ssh_dir"
    log_info "SSH keys updated for '$USER_DEVOPS' (${#DEVOPS_SSH_KEYS[@]} key(s))"

    # Create runner user (application runtime)
    if ! user_exists "$USER_RUNNER"; then
        log_info "Creating '$USER_RUNNER' user"
        if ! run_safe "Create runner user" sudo useradd --system -m -d "$APPS_DIR" -s /usr/sbin/nologin -G apps "$USER_RUNNER"; then
            component_fail "users" "Failed to create '$USER_RUNNER' user"
            return 1
        fi
    else
        log_info "User '$USER_RUNNER' already exists, skipping"
    fi

    # Create gh-actions user (CI/CD automation)
    if ! user_exists "$USER_GHACTIONS"; then
        log_info "Creating '$USER_GHACTIONS' user"
        # Add to docker group only if it exists
        local groups="apps"
        if group_exists "docker"; then
            groups="apps,docker"
        fi
        if ! run_safe "Create gh-actions user" sudo useradd --system -m -d "$APPS_DIR" -s /bin/bash -G "$groups" "$USER_GHACTIONS"; then
            component_fail "users" "Failed to create '$USER_GHACTIONS' user"
            return 1
        fi
    else
        log_info "User '$USER_GHACTIONS' already exists, skipping"
    fi

    # Setup /opt/apps directory with proper permissions
    if [[ ! -d "$APPS_DIR" ]]; then
        log_info "Creating $APPS_DIR directory"
        sudo mkdir -p "$APPS_DIR"
    fi

    log_info "Setting permissions on $APPS_DIR"
    sudo chown "$USER_RUNNER:apps" "$APPS_DIR"
    sudo chmod 2775 "$APPS_DIR"  # setgid bit for group inheritance

    component_success "users"
    return 0
}
