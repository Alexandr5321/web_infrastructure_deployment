#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

ADMIN_USER="admin-user"
DEPLOY_USER="deploy-user"

# Перед запуском:
# export ADMIN_PUBLIC_KEY="ssh-ed25519 AAAA..."
# export DEPLOY_PUBLIC_KEY="ssh-ed25519 AAAA..."

if [[ -z "${ADMIN_PUBLIC_KEY:-}" ]]; then
    echo "ERROR: ADMIN_PUBLIC_KEY is not set"
    echo 'Example: export ADMIN_PUBLIC_KEY="ssh-ed25519 AAAA..."'
    exit 1
fi

if [[ -z "${DEPLOY_PUBLIC_KEY:-}" ]]; then
    echo "ERROR: DEPLOY_PUBLIC_KEY is not set"
    echo 'Example: export DEPLOY_PUBLIC_KEY="ssh-ed25519 AAAA..."'
    exit 1
fi

# ============================================================
# Root check
# ============================================================

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: run this script with sudo"
    echo "Example: sudo ./setup.sh"
    exit 1
fi

echo "=== Creating users ==="

# ============================================================
# Users
# ============================================================

if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$ADMIN_USER"
fi

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$DEPLOY_USER"
fi

# admin-user gets sudo access
usermod -aG sudo "$ADMIN_USER"

# ============================================================
# SSH directories
# ============================================================

echo "=== Configuring SSH keys ==="

for USER in "$ADMIN_USER" "$DEPLOY_USER"; do
    HOME_DIR=$(getent passwd "$USER" | cut -d: -f6)

    install -d -m 700 -o "$USER" -g "$USER" \
        "$HOME_DIR/.ssh"

    touch "$HOME_DIR/.ssh/authorized_keys"

    chown "$USER:$USER" "$HOME_DIR/.ssh/authorized_keys"
    chmod 600 "$HOME_DIR/.ssh/authorized_keys"
done

# Install public keys
echo "$ADMIN_PUBLIC_KEY" > \
    "/home/$ADMIN_USER/.ssh/authorized_keys"

echo "$DEPLOY_PUBLIC_KEY" > \
    "/home/$DEPLOY_USER/.ssh/authorized_keys"

chown "$ADMIN_USER:$ADMIN_USER" \
    "/home/$ADMIN_USER/.ssh/authorized_keys"

chown "$DEPLOY_USER:$DEPLOY_USER" \
    "/home/$DEPLOY_USER/.ssh/authorized_keys"

chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"

# ============================================================
# SSH configuration
# ============================================================

echo "=== Configuring SSH ==="

SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup original configuration
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup"

# Remove previous settings if they exist
sed -i \
    -e '/^[[:space:]]*PasswordAuthentication[[:space:]]/d' \
    -e '/^[[:space:]]*PubkeyAuthentication[[:space:]]/d' \
    -e '/^[[:space:]]*PermitRootLogin[[:space:]]/d' \
    "$SSHD_CONFIG"

cat >> "$SSHD_CONFIG" <<'EOF'

# Managed by web infrastructure deployment
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
EOF

# Validate SSH configuration BEFORE restart
sshd -t

# ============================================================
# Firewall
# ============================================================

echo "=== Configuring UFW ==="

apt-get update
apt-get install -y ufw

# Default policy: deny everything incoming
ufw default deny incoming

# Allow outgoing traffic
ufw default allow outgoing

# SSH
ufw allow 22/tcp

# HTTP
ufw allow 80/tcp

# HTTPS
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# ============================================================
# Restart SSH
# ============================================================

echo "=== Restarting SSH ==="

if systemctl list-unit-files | grep -q '^ssh\.service'; then
    systemctl restart ssh
else
    systemctl restart sshd
fi

# ============================================================
# Docker
# ============================================================

echo "=== Checking Docker ==="

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed."
    echo "Please install Docker and Docker Compose first."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin is not installed."
    exit 1
fi

# ============================================================
# Start infrastructure
# ============================================================

echo "=== Starting Docker infrastructure ==="

cd "$(dirname "$0")"

docker compose up -d --build

echo
echo "============================================================"
echo "Infrastructure started successfully."
echo "============================================================"
echo

docker compose ps

echo
echo "SSH:"
echo "  Password authentication: disabled"
echo "  Root login: disabled"
echo "  Public-key authentication: enabled"
echo
echo "Users:"
echo "  $ADMIN_USER"
echo "  $DEPLOY_USER"
echo
echo "Firewall:"
ufw status
