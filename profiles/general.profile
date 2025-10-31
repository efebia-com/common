# General Purpose Server Profile
# Defines components and configuration for general-purpose servers

# Server type identifier
SERVER_TYPE="general"

# Components to install (in order)
COMPONENTS=(
    "system"
    "terminal"
    "docker"
    "users"
    "ssh"
)

# Component-specific configuration

# User accounts
export USER_DEVOPS="devops"
export USER_RUNNER="runner"
export USER_GHACTIONS="gh-actions"

# Application directory
export APPS_DIR="/opt/apps"

# SSH key for devops user
export DEVOPS_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKwF12bPWwBPKF29ERFtj7H4a3yeYNj5PrVsvqFEG4J8 devops@efebia.com"

# Notes:
# - General purpose servers get minimal setup: system, terminal, Docker, users, SSH
# - No Node.js, Cloudflared, or database components by default
# - Can be used as a base for custom server types
