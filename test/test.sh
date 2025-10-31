#!/bin/bash
# Test runner for OVH provisioning scripts
# Tests all profiles in isolated Docker containers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate.sh"

# Available profiles
AVAILABLE_PROFILES=("backend" "database" "general")

# Parse command line arguments
PROFILES_TO_TEST=()
KEEP_RUNNING=false
SKIP_BUILD=false
VERBOSE=false

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [PROFILES...]

Test OVH provisioning scripts in Docker containers.

OPTIONS:
    -h, --help          Show this help message
    -k, --keep          Keep containers running after test (for debugging)
    -s, --skip-build    Skip Docker image build (use existing image)
    -v, --verbose       Show verbose output (all logs)
    -a, --all           Test all profiles (default if none specified)

PROFILES:
    backend             Test backend server provisioning
    database            Test database server provisioning
    general             Test general purpose server provisioning

EXAMPLES:
    $0                  # Test all profiles
    $0 backend          # Test only backend profile
    $0 -k general       # Test general profile and keep container running
    $0 -v backend database  # Test backend and database with verbose output

EOF
    exit 0
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -k|--keep)
            KEEP_RUNNING=true
            shift
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -a|--all)
            PROFILES_TO_TEST=("${AVAILABLE_PROFILES[@]}")
            shift
            ;;
        backend|database|general)
            PROFILES_TO_TEST+=("$1")
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Default to all profiles if none specified
if [[ ${#PROFILES_TO_TEST[@]} -eq 0 ]]; then
    PROFILES_TO_TEST=("${AVAILABLE_PROFILES[@]}")
fi

log_info "Testing profiles: ${PROFILES_TO_TEST[*]}"

# Build Docker image
if [[ "$SKIP_BUILD" == "false" ]]; then
    log_info "Building test Docker image..."
    cd "$PROJECT_DIR"
    if docker compose -f "$COMPOSE_FILE" build --quiet; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
else
    log_info "Skipping Docker image build"
fi

# Test each profile
RESULTS=()
FAILED_PROFILES=()

for profile in "${PROFILES_TO_TEST[@]}"; do
    log_info "=========================================="
    log_info "Testing profile: $profile"
    log_info "=========================================="

    # Start container
    log_info "Starting container for $profile..."
    if ! docker compose -f "$COMPOSE_FILE" up -d "$profile" 2>&1 | grep -v "is up-to-date"; then
        log_error "Failed to start container for $profile"
        RESULTS+=("$profile: FAILED (container start)")
        FAILED_PROFILES+=("$profile")
        continue
    fi

    # Wait for container to be fully ready
    log_info "Waiting for container to be ready..."
    sleep 2

    # Run provisioning script
    log_info "Running provisioning for $profile..."

    if [[ "$VERBOSE" == "true" ]]; then
        # Show all output in verbose mode
        if docker exec "test-$profile" bash -c "cd /provisioning && PROFILE=$profile bash post-install.sh"; then
            log_success "Provisioning completed for $profile"
            PROVISION_SUCCESS=true
        else
            log_error "Provisioning failed for $profile"
            PROVISION_SUCCESS=false
        fi
    else
        # Show only summary in normal mode
        if docker exec "test-$profile" bash -c "cd /provisioning && PROFILE=$profile bash post-install.sh" > "/tmp/provision-$profile.log" 2>&1; then
            log_success "Provisioning completed for $profile"
            PROVISION_SUCCESS=true
        else
            log_error "Provisioning failed for $profile"
            log_info "Check logs: /tmp/provision-$profile.log"
            PROVISION_SUCCESS=false
        fi
    fi

    if [[ "$PROVISION_SUCCESS" == "true" ]]; then
        # Run validation
        log_info "Validating installation for $profile..."
        if docker exec "test-$profile" bash /provisioning/test/validate.sh "$profile"; then
            log_success "Validation passed for $profile"
            RESULTS+=("$profile: SUCCESS")
        else
            log_error "Validation failed for $profile"
            RESULTS+=("$profile: FAILED (validation)")
            FAILED_PROFILES+=("$profile")
        fi
    else
        RESULTS+=("$profile: FAILED (provisioning)")
        FAILED_PROFILES+=("$profile")
    fi

    # Show provisioning log location
    if [[ "$VERBOSE" == "false" ]]; then
        log_info "Container log: docker logs test-$profile"
        log_info "Provisioning log: docker exec test-$profile cat /var/log/post-install.log"
    fi

    # Clean up or keep running
    if [[ "$KEEP_RUNNING" == "false" ]]; then
        log_info "Stopping container for $profile..."
        docker compose -f "$COMPOSE_FILE" stop "$profile" >/dev/null 2>&1
        docker compose -f "$COMPOSE_FILE" rm -f "$profile" >/dev/null 2>&1
    else
        log_info "Container kept running: test-$profile"
        log_info "  Exec into container: docker exec -it test-$profile bash"
        log_info "  View logs: docker logs test-$profile"
        log_info "  Stop container: docker compose -f test/docker-compose.yml stop $profile"
    fi

    echo
done

# Print summary
log_info "=========================================="
log_info "Test Summary"
log_info "=========================================="

for result in "${RESULTS[@]}"; do
    if [[ "$result" =~ SUCCESS ]]; then
        log_success "$result"
    else
        log_error "$result"
    fi
done

# Final status
if [[ ${#FAILED_PROFILES[@]} -eq 0 ]]; then
    log_success "All tests passed!"
    exit 0
else
    log_error "Some tests failed: ${FAILED_PROFILES[*]}"
    if [[ "$KEEP_RUNNING" == "false" ]]; then
        log_info "Re-run with -k flag to keep containers running for debugging"
    fi
    exit 1
fi
