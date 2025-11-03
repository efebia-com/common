#!/bin/bash
# terminal.sh - Ghostty terminal support setup

setup_terminal() {
    component_start "terminal"

    local terminfo_url="https://raw.githubusercontent.com/efebia-com/common/master/xterm-ghostty.terminfo"
    local terminfo_file="/tmp/xterm-ghostty.terminfo"

    # Download terminfo file
    log_info "Downloading Ghostty terminfo definition"
    if ! download_file "$terminfo_url" "$terminfo_file"; then
        component_fail "terminal" "Failed to download terminfo file"
        return 1
    fi

    # Compile and install terminfo
    log_info "Installing Ghostty terminfo"
    if ! run_safe "Compile terminfo" sudo tic -x "$terminfo_file"; then
        component_fail "terminal" "Failed to compile terminfo"
        return 1
    fi

    # Add TERM fix to /etc/skel/.bashrc (for new users)
    local bashrc_fix='[[ "$TERM" == "xterm-ghostty" ]] && export TERM=xterm-256color'

    log_info "Adding TERM fix to /etc/skel/.bashrc"
    if [[ -f /etc/skel/.bashrc ]]; then
        add_line_if_missing "/etc/skel/.bashrc" "$bashrc_fix"
    fi

    # Add TERM fix to root's .bashrc
    log_info "Adding TERM fix to /root/.bashrc"
    if [[ -f /root/.bashrc ]]; then
        add_line_if_missing "/root/.bashrc" "$bashrc_fix"
    fi

    # Add TERM fix to ubuntu user's .bashrc if exists
    if [[ -f /home/ubuntu/.bashrc ]]; then
        log_info "Adding TERM fix to /home/ubuntu/.bashrc"
        add_line_if_missing "/home/ubuntu/.bashrc" "$bashrc_fix"
    fi

    # Cleanup
    rm -f "$terminfo_file"

    component_success "terminal"
    return 0
}
