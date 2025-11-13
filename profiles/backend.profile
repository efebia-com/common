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

# SSH keys for devops user (team members - brutally replaced on each run)
export DEVOPS_SSH_KEYS=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICKlUsqkYIlxWMG35LsKNkwRK5mogpnyWAPaRatqvSmZ calogero@efebia.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFnyyCfWOpFxa/H/qu1pyMsq7RGK83R2qp4AUda8t4F1 smastella@efebia.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQxEl34HJMatEi+w5a88NmvuPITjdzr/1Pbb7erqTQR fcafagna@efebia.com"
)

# Database configuration (not needed for backend)
export DB_TYPE="none"
