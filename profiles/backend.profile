# Backend Server Profile
# Defines components and configuration for backend application servers

# Server type identifier
SERVER_TYPE="backend"

# Components to install (in order)
COMPONENTS=(
    "system"
    "terminal"
    "docker"
    "users"
    "cloudflared"
    "ssh"
)

# Component-specific configuration
# These can override defaults from individual component files

# Node.js version
export NODE_VERSION="24"

# User accounts
export USER_DEVOPS="devops"
export USER_RUNNER="runner"
export USER_GHACTIONS="gh-actions"

# Application directory
export APPS_DIR="/opt/apps"

# SSH key for devops user
export DEVOPS_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKwF12bPWwBPKF29ERFtj7H4a3yeYNj5PrVsvqFEG4J8 devops@efebia.com"

# Database configuration (not needed for backend)
export DB_TYPE="none"
