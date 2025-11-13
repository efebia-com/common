# Database Server Profile
# Defines components and configuration for database servers

# Server type identifier
SERVER_TYPE="database"

# Components to install (in order)
COMPONENTS=(
    "system"
    "terminal"
    "docker"
    "users"
    "database"
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

# Database configuration
# Options: none, postgres, mysql, both
export DB_TYPE="none"  # Default to none, run databases in Docker

# Installation method: docker, native, both
export INSTALL_METHOD="docker"  # Default to Docker-only

# Notes:
# - To install PostgreSQL natively: set DB_TYPE="postgres" and INSTALL_METHOD="native"
# - To install MySQL natively: set DB_TYPE="mysql" and INSTALL_METHOD="native"
# - To support both Docker and native: set INSTALL_METHOD="both"
