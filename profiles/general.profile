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

# SSH keys for devops user (team members - brutally replaced on each run)
export DEVOPS_SSH_KEYS=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICKlUsqkYIlxWMG35LsKNkwRK5mogpnyWAPaRatqvSmZ calogero@efebia.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFnyyCfWOpFxa/H/qu1pyMsq7RGK83R2qp4AUda8t4F1 smastella@efebia.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQxEl34HJMatEi+w5a88NmvuPITjdzr/1Pbb7erqTQR fcafagna@efebia.com"
)

# Notes:
# - General purpose servers get minimal setup: system, terminal, Docker, users, SSH
# - No Node.js, Cloudflared, or database components by default
# - Can be used as a base for custom server types
