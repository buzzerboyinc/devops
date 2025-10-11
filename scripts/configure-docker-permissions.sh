#!/bin/bash

# configure-docker-permissions.sh
# Script to configure Docker permissions for all users
# Author: DevOps Team
# Date: $(date +%Y-%m-%d)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed on this system"
        exit 1
    fi
    log_info "Docker is installed: $(docker --version)"
}

# Check if running with appropriate permissions
check_permissions() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges"
        exit 1
    fi
}

# Create docker group if it doesn't exist
create_docker_group() {
    if ! getent group docker > /dev/null 2>&1; then
        log_info "Creating docker group..."
        sudo groupadd docker
        log_success "Docker group created"
    else
        log_info "Docker group already exists"
    fi
}

# Add user to docker group
add_user_to_docker_group() {
    local username=${1:-$(whoami)}
    
    if groups "$username" | grep -q docker; then
        log_info "User '$username' is already in docker group"
    else
        log_info "Adding user '$username' to docker group..."
        sudo usermod -aG docker "$username"
        log_success "User '$username' added to docker group"
        log_warning "User needs to log out and back in for group changes to take effect"
    fi
}

# Configure Docker socket permissions
configure_socket_permissions() {
    log_info "Configuring Docker socket permissions..."
    
    # Change socket permissions to allow group access
    sudo chmod 666 /var/run/docker.sock
    
    # Verify permissions
    local perms=$(ls -la /var/run/docker.sock | cut -d' ' -f1)
    log_success "Docker socket permissions set to: $perms"
}

# Create systemd service to set permissions on boot
create_systemd_service() {
    log_info "Creating systemd service for persistent Docker permissions..."
    
    cat << EOF | sudo tee /etc/systemd/system/docker-permissions.service > /dev/null
[Unit]
Description=Set Docker socket permissions
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/chmod 666 /var/run/docker.sock
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable docker-permissions.service
    sudo systemctl start docker-permissions.service
    
    log_success "Systemd service created and enabled"
}

# Add all existing users to docker group
add_all_users_to_docker() {
    log_info "Adding all existing users to docker group..."
    
    # Get all regular users (UID >= 1000)
    local users=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)
    
    for user in $users; do
        if [[ "$user" != "nobody" ]]; then
            add_user_to_docker_group "$user"
        fi
    done
}

# Test Docker access
test_docker_access() {
    log_info "Testing Docker access..."
    
    if docker ps > /dev/null 2>&1; then
        log_success "Docker is accessible without sudo"
    else
        log_warning "Docker still requires sudo or user needs to log out/in"
    fi
}

# Display summary
display_summary() {
    log_info "Docker Configuration Summary:"
    echo "============================="
    
    # Check Docker group
    local docker_users=$(getent group docker | cut -d: -f4)
    echo -e "${GREEN}✓${NC} Docker group members: ${docker_users:-none}"
    
    # Check socket permissions
    local socket_perms=$(ls -la /var/run/docker.sock | awk '{print $1}')
    echo -e "${GREEN}✓${NC} Docker socket permissions: $socket_perms"
    
    # Check systemd service
    if systemctl is-enabled docker-permissions.service &> /dev/null; then
        echo -e "${GREEN}✓${NC} Persistent permissions service: enabled"
    else
        echo -e "${YELLOW}!${NC} Persistent permissions service: not enabled"
    fi
    
    echo "============================="
    log_warning "Users may need to log out and back in for group changes to take effect"
}

# Main function
main() {
    log_info "Configuring Docker permissions for all users..."
    
    # Get target user if provided
    local target_user=${1:-""}
    
    check_docker_installed
    check_permissions
    create_docker_group
    
    if [[ -n "$target_user" ]]; then
        add_user_to_docker_group "$target_user"
    else
        # Ask if user wants to add all users or just current user
        echo "Choose an option:"
        echo "1) Add only current user ($(whoami)) to docker group"
        echo "2) Add all existing users to docker group"
        echo "3) Skip user configuration"
        read -p "Enter choice (1-3): " choice
        
        case $choice in
            1)
                add_user_to_docker_group
                ;;
            2)
                add_all_users_to_docker
                ;;
            3)
                log_info "Skipping user configuration"
                ;;
            *)
                log_warning "Invalid choice, adding current user only"
                add_user_to_docker_group
                ;;
        esac
    fi
    
    configure_socket_permissions
    create_systemd_service
    test_docker_access
    display_summary
    
    log_success "Docker permissions configured successfully!"
}

# Show usage if help requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [username]"
    echo ""
    echo "Configure Docker permissions for all users"
    echo ""
    echo "Options:"
    echo "  username    Optional: specific user to add to docker group"
    echo "  -h, --help  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive mode"
    echo "  $0 username          # Add specific user to docker group"
    exit 0
fi

# Run main function
main "$@"