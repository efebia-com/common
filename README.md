# Common Server Configuration Files

Shared configuration files and utilities for OVH bare metal server provisioning.

## Overview

This repository provides a modular, maintainable provisioning system for OVH bare metal servers with support for multiple server types:

- **Backend servers** - Application servers with Docker and Cloudflared
- **Database servers** - Database hosts with Docker (and optional native database installs)
- **General purpose servers** - Minimal baseline setup with Docker and SSH hardening

## Architecture

The system uses a **component-based architecture** for maintainability and flexibility:

```
common/
├── lib/                    # Reusable components
│   ├── base.sh            # Core utilities, logging, error handling
│   ├── system.sh          # System updates and packages
│   ├── terminal.sh        # Ghostty terminal support
│   ├── users.sh           # User account management
│   ├── docker.sh          # Docker CE installation
│   ├── nodejs.sh          # Node.js via NVM
│   ├── cloudflared.sh     # Cloudflare Tunnel daemon
│   ├── ssh.sh             # SSH security hardening
│   └── database.sh        # Database setup (native or Docker)
├── profiles/              # Server type definitions
│   ├── backend.profile    # Backend server components
│   ├── database.profile   # Database server components
│   └── general.profile    # General purpose components
└── post-install.sh        # Unified entry point (requires ?profile=NAME)
```

### Key Benefits

- **Modular** - Each component is self-contained and testable
- **Maintainable** - Easy to understand, modify, and debug
- **Flexible** - Support multiple server types with shared components
- **Observable** - Detailed logging with component tags and status tracking
- **Idempotent** - Safe to re-run without breaking existing setups
- **Resource-optimized** - Each server type gets only what it needs

## Prerequisites

Before running the provisioning scripts, ensure:

- **Operating System:** Ubuntu 24.04 (recommended)
- **User Requirements:** Script must be run as a user with passwordless sudo access (default `ubuntu` user on OVH)
- **Internet Connectivity:** Required to download components and packages
- **Disk Space:** At least 5GB free space recommended

## Usage in OVH

In the OVH "Post-Installation Script" field, use the download-then-execute pattern:

### Backend Server

```bash
#!/bin/bash
curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh' -o /tmp/post-install.sh
bash /tmp/post-install.sh backend
```

**Installs:**
- System updates and essential packages
- Ghostty terminal support
- Docker CE with Compose and Buildx plugins
- User accounts (devops, runner, gh-actions)
- Cloudflared
- SSH hardening (key-only authentication)

### Database Server

```bash
#!/bin/bash
curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh' -o /tmp/post-install.sh
bash /tmp/post-install.sh database
```

**Installs:**
- System updates and essential packages
- Ghostty terminal support
- Docker CE with Compose and Buildx plugins
- User accounts (devops, runner, gh-actions)
- SSH hardening (key-only authentication)
- Database support (Docker-based by default)

**Note:** Database servers do NOT install Cloudflared to save resources.

### General Purpose Server

```bash
#!/bin/bash
curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh' -o /tmp/post-install.sh
bash /tmp/post-install.sh general
```

**Installs:**
- System updates and essential packages
- Ghostty terminal support
- Docker CE with Compose and Buildx plugins
- User accounts (devops, runner, gh-actions)
- SSH hardening (key-only authentication)

**Note:** Minimal setup for general-purpose use. No Cloudflared or database components.

### Manual Execution

For testing or manual server setup:

```bash
# Download the script
curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh' -o post-install.sh

# Execute with profile as argument
bash post-install.sh backend

# Or using environment variable
PROFILE=backend bash post-install.sh
```

### Important Notes

⚠️ **Requirements:**
- The profile parameter is mandatory (backend, database, or general)
- Passwordless sudo access is required for the executing user
- OVH's default `ubuntu` user already has this configured
- The script will run pre-flight checks and fail early if requirements aren't met

## User Accounts

All server types create three user accounts:

### devops (Human Operator)
- Shell: `/bin/bash`
- Groups: `apps`, `docker`
- Purpose: Manual server management and SSH access
- SSH key authentication configured

### runner (Application Runtime)
- Shell: `/usr/sbin/nologin` (system user)
- Home: `/opt/apps`
- Groups: `apps`
- Purpose: Running applications
- Primary owner of `/opt/apps`

### gh-actions (CI/CD Automation)
- Shell: `/bin/bash` (system user)
- Home: `/opt/apps`
- Groups: `apps`, `docker`
- Purpose: GitHub Actions deployments

## Directory Structure

```
/opt/apps/
  └── (owned by runner:apps, 775 permissions with setgid)
```

All users in the `apps` group can write to `/opt/apps`. The setgid bit ensures new files inherit the `apps` group.

## Logging and Debugging

All provisioning scripts log to:
- **Root users:** `/var/log/post-install.log`
- **Non-root users:** `~/post-install.log`

### Log Format

```
[2025-10-31 14:23:45] [INFO] [system] Installing essential packages
[2025-10-31 14:24:12] [SUCCESS] [docker] Docker installed successfully: Docker version 24.0.7
[2025-10-31 14:24:13] [ERROR] [nodejs] Failed to download NVM installer
```

### Component Status Tracking

Each component reports success or failure independently. At the end of provisioning, you'll see a summary:

```
===================================================================
Provisioning Summary
===================================================================
[SUCCESS] Succeeded (6):
[SUCCESS]   ✓ system
[SUCCESS]   ✓ terminal
[SUCCESS]   ✓ docker
[SUCCESS]   ✓ users
[SUCCESS]   ✓ nodejs
[SUCCESS]   ✓ ssh
[ERROR] Failed (1):
[ERROR]   ✗ cloudflared
```

This makes debugging much easier - you know exactly what failed and where to look.

## Troubleshooting

### Permission Denied Errors

**Problem:** Errors like `Permission denied`, `Operation not permitted`, or `Authentication failure`

**Solution:**
1. Ensure you're running as the `ubuntu` user (or another user with sudo access)
2. Verify passwordless sudo is configured:
   ```bash
   sudo -n true
   ```
   If this asks for a password, configure `/etc/sudoers`:
   ```bash
   echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu
   ```

### apt-get Update Fails (Exit Code 100)

**Problem:** System component fails with `Failed to update package lists`

**Causes:**
- Running without sudo privileges
- Another package manager process is running (apt lock)
- Network connectivity issues

**Solution:**
1. Check if another apt process is running:
   ```bash
   sudo lsof /var/lib/dpkg/lock-frontend
   ```
2. Wait for other updates to complete or kill stale processes
3. Ensure you have sudo access (see Permission Denied above)

### SSH Service Restart Fails

**Problem:** SSH component fails with `Authentication failure` when restarting sshd

**Solution:**
- This happens when running without sudo
- The script now includes pre-flight checks to catch this early
- Ensure the user has passwordless sudo configured

### Pre-flight Checks Fail

**Problem:** Script exits early with pre-flight check failures

**Common Issues:**
1. **No sudo access:** Configure passwordless sudo for your user
2. **No internet connectivity:** Check network connection and DNS
3. **Low disk space:** Free up space (5GB+ recommended)
4. **Wrong OS:** Script is designed for Ubuntu 24.04

### Profile Not Found

**Problem:** `Profile not found: PROFILENAME`

**Solution:**
- Valid profiles are: `backend`, `database`, `general`
- Check spelling and use lowercase
- Example: `bash post-install.sh backend`

### Component Already Installed Messages

**Problem:** Seeing "already installed" for many components

**This is normal!** The scripts are idempotent. If you re-run provisioning, components that are already installed will be skipped. This is not an error.

## Customization

### Creating a Custom Server Type

1. **Create a new profile** in `profiles/`:

```bash
# profiles/loadbalancer.profile
SERVER_TYPE="loadbalancer"

COMPONENTS=(
    "system"
    "terminal"
    "docker"
    "users"
    "ssh"
)

# Custom configuration
export USER_DEVOPS="devops"
export APPS_DIR="/opt/apps"
```

2. **Use in OVH with the new profile**:

```bash
#!/bin/bash
curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh' -o /tmp/post-install.sh
bash /tmp/post-install.sh loadbalancer
```

That's it! No need to create a separate entry point script - the unified `post-install.sh` handles all profiles.

### Modifying Database Server Setup

To install PostgreSQL natively on database servers, edit `profiles/database.profile`:

```bash
# Database configuration
export DB_TYPE="postgres"        # or "mysql" or "both"
export INSTALL_METHOD="native"   # or "both" for Docker + native
```

## Component Reference

### base.sh
Core utilities for all components:
- Logging functions (`log_info`, `log_error`, `log_success`)
- Component lifecycle (`component_start`, `component_success`, `component_fail`)
- Idempotency checks (`command_exists`, `user_exists`, `package_installed`)
- File operations (`update_config`, `add_line_if_missing`)

### system.sh
System updates and essential package installation:
- `apt-get update` and `apt-get upgrade`
- Essential packages: curl, wget, git, vim, htop, build-essential

### terminal.sh
Ghostty terminal support:
- Downloads and compiles terminfo
- Adds TERM fix to bashrc files
- Enables full terminal capabilities for Ghostty

### users.sh
User account and group management:
- Creates `apps` group
- Creates `devops`, `runner`, `gh-actions` users
- Sets up SSH keys
- Configures `/opt/apps` with proper permissions

### docker.sh
Docker CE installation:
- Adds Docker GPG key and repository
- Installs Docker CE, CLI, containerd, buildx, compose plugins
- Enables and starts Docker service

### nodejs.sh
Node.js installation via NVM:
- Downloads and installs NVM
- Installs specified Node.js version (default: v24)
- Sets default Node.js version

### cloudflared.sh
Cloudflare Tunnel daemon:
- Adds Cloudflare GPG key and repository
- Installs cloudflared package

### ssh.sh
SSH security hardening:
- Disables password authentication
- Disables challenge-response authentication
- Enables public key authentication only
- Restricts root login to key-only

### database.sh
Database setup (flexible):
- Supports Docker-only, native, or hybrid installations
- Can install PostgreSQL and/or MySQL natively
- Configurable via environment variables

## Ghostty Terminfo

Terminfo database entry for [Ghostty terminal emulator](https://ghostty.org/) to enable full terminal capabilities on remote servers.

### Standalone Installation

If you only need the terminfo (not the full server setup):

```bash
curl -fsSL https://raw.githubusercontent.com/efebia-com/common/master/xterm-ghostty.terminfo | tic -x -
```

### What This Fixes

Without this terminfo, when connecting to remote servers via Ghostty you may see:
- `Error opening terminal: xterm-ghostty` when running htop, vim, etc.
- Broken colors or UI in terminal applications

This terminfo file enables:
- Full color support (256 colors)
- Proper terminal capabilities
- htop, vim, tmux, and other ncurses applications work correctly

### About

Exported from Ghostty 1.0.1 on Ubuntu 24.04.

## Migration from Old System

The old monolithic `post-install.sh` is preserved as `post-install.sh.old` for reference.

**Key differences:**
- **Old:** Single 110-line script, hard to maintain
- **New:** Modular components, easy to understand and debug
- **Old:** All servers identical
- **New:** Different server types with optimized installs
- **Old:** Basic error handling
- **New:** Component-level status tracking and detailed logging

**To migrate:**
- Replace old URL with new unified URL (add `?profile=backend` parameter) in OVH
- New system is idempotent and safe to re-run on existing servers

## Troubleshooting

### Component Failed

Check the log file for detailed error messages:

```bash
sudo tail -f /var/log/post-install.log
# or
tail -f ~/post-install.log
```

Look for the `[ERROR]` tag with the component name to see what failed.

### SSH Access Issues

If you can't SSH in after provisioning:
- Verify the `devops` user was created: `id devops`
- Check SSH key was added: `sudo cat /home/devops/.ssh/authorized_keys`
- Verify SSH service is running: `sudo systemctl status sshd`
- Check SSH config: `sudo grep -E '(PasswordAuthentication|PubkeyAuthentication)' /etc/ssh/sshd_config`

### Docker Not Working

Verify Docker installation:
```bash
docker --version
sudo systemctl status docker
```

Check if user is in docker group:
```bash
groups devops
groups gh-actions
```

### Re-running Provisioning

All scripts are idempotent and safe to re-run:

```bash
# Download and run locally for debugging
curl -fsSL 'https://raw.githubusercontent.com/efebia-com/common/master/post-install.sh?profile=backend' -o /tmp/provision.sh
sudo bash /tmp/provision.sh backend

# Or set PROFILE environment variable
sudo PROFILE=backend bash /tmp/provision.sh
```

## Testing

A comprehensive Docker-based test infrastructure is available to test provisioning scripts locally before deploying to OVH servers.

### Quick Start

```bash
cd test
bash test.sh
```

This will:
- Build Ubuntu 24.04 test containers
- Test all profiles (backend, database, general)
- Run validation checks
- Show detailed results

### Test Specific Profiles

```bash
# Test only backend
bash test.sh backend

# Test with verbose output and keep container running
bash test.sh -k -v backend

# Skip Docker image rebuild for faster testing
bash test.sh -s database
```

### What Gets Tested

- ✅ All component installations
- ✅ User and group creation
- ✅ Docker-in-Docker functionality
- ✅ SSH hardening configuration
- ✅ Service startup (systemd)
- ✅ Idempotency (safe re-runs)
- ✅ Profile-specific components

### Benefits

- **Fast iteration** - Test changes in seconds without OVH servers
- **Confident deployment** - Know scripts work before production
- **Easy debugging** - Keep containers running to inspect state
- **Comprehensive validation** - Automated checks for all components

See [test/README.md](test/README.md) for complete documentation.

## Contributing

To add new components:

1. Create component file in `lib/` (e.g., `lib/newfeature.sh`)
2. Implement `setup_newfeature()` function
3. Add component to appropriate profiles
4. Test idempotency and error handling
5. Update this README

## License

This repository is maintained by [efebia.com](https://efebia.com) for internal use.
