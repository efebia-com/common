# OVH Provisioning Test Infrastructure

Comprehensive testing environment for OVH bare metal server provisioning scripts using Docker containers.

## Overview

This test infrastructure allows you to:
- **Test provisioning scripts locally** without spinning up OVH servers
- **Fast iteration cycle** - Make changes and test immediately
- **Test all profiles** - Backend, database, and general purpose servers
- **Validate results** - Automatic checks that installations succeeded
- **Debug easily** - Keep containers running to inspect state
- **Realistic environment** - Ubuntu 24.04 with systemd, as close to OVH as possible

## Architecture

### Components

```
test/
├── Dockerfile              # Ubuntu 24.04 with systemd support
├── docker-compose.yml      # Test services for each profile
├── test.sh                 # Main test runner script
├── validate.sh             # Validation checks
└── README.md              # This file
```

### How It Works

1. **Docker Image** - Ubuntu 24.04 with systemd enabled (for SSH, Docker daemon)
2. **Privileged Containers** - Required for Docker-in-Docker testing
3. **Volume Mounts** - Your local repo is mounted to test uncommitted changes
4. **Validation** - Automated checks verify installation success
5. **Isolation** - Each profile runs in its own container

## Quick Start

### Test All Profiles

```bash
cd test
bash test.sh
```

This will:
- Build the test Docker image
- Test backend, database, and general profiles
- Run validation checks
- Show summary of results
- Clean up containers

### Test Specific Profile

```bash
# Test only backend
bash test.sh backend

# Test backend and database
bash test.sh backend database

# Test with verbose output
bash test.sh -v general
```

### Keep Container Running for Debugging

```bash
# Test and keep container running
bash test.sh -k backend

# Then inspect the container
docker exec -it test-backend bash

# Check logs
docker logs test-backend
docker exec test-backend cat /var/log/post-install.log

# When done
docker compose -f docker-compose.yml stop backend
docker compose -f docker-compose.yml rm -f backend
```

## Command Reference

### test.sh Options

```bash
bash test.sh [OPTIONS] [PROFILES...]

OPTIONS:
  -h, --help          Show help message
  -k, --keep          Keep containers running after test
  -s, --skip-build    Skip Docker image build (faster for repeated runs)
  -v, --verbose       Show all provisioning output
  -a, --all           Test all profiles (default if none specified)

PROFILES:
  backend             Backend server profile
  database            Database server profile
  general             General purpose server profile
```

### Examples

```bash
# Quick test of all profiles
bash test.sh

# Test one profile with debugging
bash test.sh -k -v backend

# Fast re-test (skip build)
bash test.sh -s database

# Test multiple specific profiles
bash test.sh backend general
```

## What Gets Tested

### All Profiles

- ✅ System updates and package installation
- ✅ Ghostty terminal support
- ✅ User accounts (devops, runner, gh-actions)
- ✅ Group creation and memberships
- ✅ Docker CE installation with plugins
- ✅ SSH security hardening
- ✅ Directory structure (/opt/apps)
- ✅ Log file creation
- ✅ Idempotency (safe to re-run)

### Backend Profile

- ✅ All common components
- ✅ Cloudflared installation
- ✅ Node.js NOT installed (uses Docker containers)

### Database Profile

- ✅ All common components
- ✅ No Cloudflared (resource optimization)
- ✅ No Node.js (not needed for databases)
- ✅ Database component support

### General Profile

- ✅ Minimal baseline setup
- ✅ No Cloudflared
- ✅ No Node.js
- ✅ No database components

## Validation Checks

The `validate.sh` script performs comprehensive checks:

### User & Group Validation
- devops user exists with correct groups
- runner user exists with correct permissions
- gh-actions user exists with Docker access
- apps group exists
- docker group exists

### Docker Validation
- Docker command available
- Docker Compose plugin installed
- Docker Buildx plugin installed
- Docker service running

### SSH Validation
- SSH config file exists
- Password authentication disabled
- Public key authentication enabled
- Root login restricted

### Terminal Validation
- Ghostty terminfo installed
- TERM fixes in bashrc files

### Profile-Specific Validation
- Backend: Cloudflared installed, Node.js not installed
- Database: Cloudflared not installed, Node.js not installed
- General: Minimal setup verified

### Package Validation
- curl, wget, git, vim, htop installed

## Docker-in-Docker

This test infrastructure uses **privileged containers** to support Docker-in-Docker, which is necessary because:

1. The provisioning scripts install Docker
2. Docker daemon needs to run inside the container
3. Scripts test Docker functionality

This is the **most realistic** way to test without spinning up actual VMs.

## Troubleshooting

### Container Won't Start

```bash
# Check Docker is running
docker ps

# Check docker compose is available
docker compose version

# Try building manually
docker compose -f test/docker-compose.yml build backend
```

### Provisioning Fails

```bash
# Run with verbose output
bash test.sh -v backend

# Keep container running and inspect
bash test.sh -k backend
docker exec -it test-backend bash

# Inside container, check logs
cat /var/log/post-install.log

# Check specific component
systemctl status docker
docker --version
id devops
```

### Validation Fails

```bash
# Run validation manually
docker exec test-backend bash /provisioning/test/validate.sh backend

# Check specific issues
docker exec test-backend id devops
docker exec test-backend docker --version
docker exec test-backend cat /etc/ssh/sshd_config
```

### Docker Build Too Slow

```bash
# Skip rebuilds on subsequent runs
bash test.sh -s backend

# Or clean and rebuild
docker compose -f test/docker-compose.yml build --no-cache
```

## Workflow for Development

### Typical Development Cycle

1. **Make changes** to provisioning scripts or profiles
2. **Test immediately** without committing:
   ```bash
   cd test
   bash test.sh backend  # Tests your local changes
   ```
3. **Debug if needed**:
   ```bash
   bash test.sh -k -v backend  # Keep container, see all output
   docker exec -it test-backend bash  # Inspect container
   ```
4. **Fix issues** and re-test:
   ```bash
   bash test.sh -s backend  # Skip image rebuild for speed
   ```
5. **Commit** when all tests pass

### Before Pushing to Production

```bash
# Full test of all profiles
bash test.sh

# If all pass, push to GitHub
git add .
git commit -m "Description of changes"
git push

# Then test on OVH with real server
```

## CI/CD Integration

This test infrastructure is designed for CI/CD:

```yaml
# Example GitHub Actions workflow
name: Test Provisioning Scripts

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run provisioning tests
        run: |
          cd test
          bash test.sh
```

## Advanced Usage

### Test Specific Components

```bash
# Exec into container and run components manually
docker exec -it test-backend bash

# Inside container
cd /provisioning
source lib/base.sh
source lib/docker.sh
setup_docker  # Test just Docker installation
```

### Test Idempotency

```bash
# Run provisioning twice
bash test.sh -k backend
docker exec test-backend bash -c "cd /provisioning && PROFILE=backend bash post-install.sh"

# Should complete without errors and show "already installed" messages
```

### Custom Validation

Edit `validate.sh` to add your own checks:

```bash
# Example: Check custom configuration
log_check "Custom config file"
if [[ -f /etc/myapp/config.yml ]]; then
    log_pass
else
    log_fail "Config file not found"
fi
```

## Performance

Typical execution times (on modern hardware):

- **First build**: ~2-3 minutes (Ubuntu image download + systemd setup)
- **Subsequent tests**: ~30-60 seconds per profile
- **With `-s` flag**: ~20-30 seconds per profile

## Limitations

### What This Tests

- ✅ Component installation
- ✅ Service configuration
- ✅ User/group creation
- ✅ Directory setup
- ✅ Docker-in-Docker
- ✅ Script idempotency

### What This Doesn't Test

- ❌ OVH-specific networking
- ❌ OVH metadata service
- ❌ Actual SSH connections from outside
- ❌ Real cloud infrastructure

For final validation, always test on an actual OVH server.

## Architecture Decisions

### Why Privileged Containers?

**Problem:** The provisioning scripts install and configure Docker, which requires elevated privileges.

**Solution:** Use `privileged: true` to allow Docker-in-Docker.

**Trade-off:** Less secure but necessary for realistic testing.

### Why Systemd?

**Problem:** Services like SSH and Docker require systemd to manage them.

**Solution:** Use Ubuntu with systemd as the init system.

**Trade-off:** Heavier containers but more realistic environment.

### Why Mount Repo Read-Only?

**Problem:** Want to test local changes but prevent container from modifying source.

**Solution:** Mount with `:ro` flag.

**Benefit:** Safe testing without risk of container changing your code.

## Contributing to Tests

When adding new components:

1. **Add to `validate.sh`** - Create checks for your component
2. **Test failure cases** - Ensure validation catches missing installations
3. **Document expected behavior** - Update this README
4. **Test all profiles** - Ensure your changes don't break existing profiles

## Questions?

- **Q: Why not use actual VMs?**
  - A: Too slow for rapid iteration. Docker containers give us fast feedback.

- **Q: Why privileged containers? Isn't that insecure?**
  - A: Yes, but this is for testing only, not production. Realistic testing requires it.

- **Q: Can I test on different Ubuntu versions?**
  - A: Yes! Edit `Dockerfile` and change `FROM ubuntu:24.04` to `FROM ubuntu:22.04` etc.

- **Q: How do I add a new profile?**
  - A: Create the profile in `profiles/`, add it to `AVAILABLE_PROFILES` in `test.sh`, done!

- **Q: Tests pass but OVH deployment fails?**
  - A: Check OVH-specific things like networking, metadata, or cloud-init. Test on a real OVH server.

## Summary

This test infrastructure gives you:
- **Confidence** - Know your scripts work before deploying
- **Speed** - Test in seconds instead of minutes
- **Safety** - Test locally without affecting production
- **Visibility** - See exactly what's installed and configured
- **Maintainability** - Easy to extend as you add new components

Happy testing! 🚀
