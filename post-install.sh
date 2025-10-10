#!/bin/bash
set -e  # Exit on error

# Log to /var/log if root, otherwise to home directory
if [ "$EUID" -eq 0 ]; then
    exec > /var/log/post-install.log 2>&1
else
    exec > ~/post-install.log 2>&1
fi

echo "=== Starting post-installation setup ==="

# System update
apt update
apt upgrade -y
apt install curl apt-transport-https ca-certificates software-properties-common gnupg lsb-release -y

# Fix Ghostty terminal support EARLY - before creating users
sed -i 's/xterm-color|\*-256color)/xterm-color|*-256color|xterm-ghostty)/' /etc/skel/.bashrc

# Fix for pre-existing users (ubuntu and root - created by OVH)
sed -i 's/xterm-color|\*-256color)/xterm-color|*-256color|xterm-ghostty)/' /root/.bashrc
sed -i 's/xterm-color|\*-256color)/xterm-color|*-256color|xterm-ghostty)/' /home/ubuntu/.bashrc

# Install Ghostty terminfo from GitHub
curl -fsSL https://raw.githubusercontent.com/efebia-com/common/master/xterm-ghostty.terminfo -o /tmp/xterm-ghostty.terminfo
tic -x /tmp/xterm-ghostty.terminfo
rm /tmp/xterm-ghostty.terminfo

# Docker installation
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Verify Docker installation
systemctl enable docker
systemctl start docker

# Create application directory and group
mkdir -p /opt/apps
groupadd apps

# Create users
adduser --system --group --home /opt/apps runner
usermod -aG apps runner

adduser --disabled-password --gecos "" --shell /bin/bash devops
usermod -aG apps,docker devops

adduser --system --shell /bin/bash --home /opt/apps gh-actions
usermod -aG apps,docker gh-actions

# Set permissions on /opt/apps
chown -R runner:apps /opt/apps
chmod -R 775 /opt/apps
chmod g+s /opt/apps

# Configure SSH for devops user
mkdir -p /home/devops/.ssh
chmod 700 /home/devops/.ssh
touch /home/devops/.ssh/authorized_keys
chmod 600 /home/devops/.ssh/authorized_keys
chown -R devops:devops /home/devops/.ssh

# Add your SSH public key here
cat >> /home/devops/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAA3NzaC1lZDI1NTE5AAAAICKlUsqkYIlxWMG35LsKNkwRK5mogpnyWAPaRatqvSmZ calogero@efebia.com
EOF

# Configure SSH daemon
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config && \
  sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config || \
  echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

grep -q "^PasswordAuthentication" /etc/ssh/sshd_config && \
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || \
  echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Restart SSH to apply changes (Ubuntu uses 'ssh' not 'sshd')
systemctl restart ssh

# Install NVM and Node.js for root
export NVM_DIR="/root/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Load NVM
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js v24
nvm install 24

# Install cloudflared
cd /tmp
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
rm cloudflared-linux-amd64.deb

echo "=== Post-installation complete ==="
echo "Docker version: $(docker --version)"
echo "Node version: $(node --version)"
echo "Cloudflared version: $(cloudflared --version)"
echo "Log: /var/log/post-install.log"
