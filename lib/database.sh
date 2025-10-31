#!/bin/bash
# database.sh - Database-specific setup (PostgreSQL, MySQL, etc.)
# This module supports both Docker-based and native database installations

# Configuration
DB_TYPE="${DB_TYPE:-none}"  # none, postgres, mysql, both
INSTALL_METHOD="${INSTALL_METHOD:-docker}"  # docker, native, both

setup_database() {
    component_start "database"

    if [[ "$DB_TYPE" == "none" ]]; then
        log_info "No database installation requested (DB_TYPE=none)"
        component_success "database"
        return 0
    fi

    case "$INSTALL_METHOD" in
        docker)
            log_info "Database setup mode: Docker containers only"
            log_info "No native database installation needed"
            log_info "Databases will be run as Docker containers"
            ;;
        native)
            install_native_databases
            ;;
        both)
            log_info "Installing both native database tools and Docker support"
            install_native_databases
            ;;
        *)
            log_warning "Unknown INSTALL_METHOD: $INSTALL_METHOD, defaulting to docker-only"
            ;;
    esac

    component_success "database"
    return 0
}

install_native_databases() {
    case "$DB_TYPE" in
        postgres)
            install_postgresql
            ;;
        mysql)
            install_mysql
            ;;
        both)
            install_postgresql
            install_mysql
            ;;
        *)
            log_warning "Unknown DB_TYPE: $DB_TYPE"
            ;;
    esac
}

install_postgresql() {
    log_info "Installing PostgreSQL"

    # Install PostgreSQL
    if ! run_safe "Install PostgreSQL" apt-get install -y postgresql postgresql-contrib postgresql-client; then
        log_error "Failed to install PostgreSQL"
        return 1
    fi

    # Enable and start service
    run_safe "Enable PostgreSQL" systemctl enable postgresql
    run_safe "Start PostgreSQL" systemctl start postgresql

    local pg_version=$(psql --version 2>/dev/null || echo "unknown")
    log_info "PostgreSQL installed: $pg_version"

    return 0
}

install_mysql() {
    log_info "Installing MySQL"

    # Install MySQL server
    if ! run_safe "Install MySQL" apt-get install -y mysql-server mysql-client; then
        log_error "Failed to install MySQL"
        return 1
    fi

    # Enable and start service
    run_safe "Enable MySQL" systemctl enable mysql
    run_safe "Start MySQL" systemctl start mysql

    local mysql_version=$(mysql --version 2>/dev/null || echo "unknown")
    log_info "MySQL installed: $mysql_version"

    return 0
}
