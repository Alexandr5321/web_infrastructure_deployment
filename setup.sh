#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ADMIN_USER="admin-user"
DEPLOY_USER="deploy-user"

echo "========================================"
echo " Web infrastructure deployment"
echo "========================================"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: run this script with sudo:"
    echo "  sudo ./setup.sh"
    exit 1
fi

cd "$PROJECT_DIR"

# --------------------------------------------------
# 1. Install required packages
# --------------------------------------------------

echo
echo "[1/7] Installing required packages..."

apt-get update
apt-get install -y \
    docker.io \
    docker-compose-v2 \
    openssh-server \
    ufw

systemctl enable --now docker
systemctl enable --now ssh

# --------------------------------------------------
# 2. Create users
# --------------------------------------------------

echo
echo "[2/7] Creating users..."

if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$ADMIN_USER"
fi

if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$DEPLOY_USER"
fi

# --------------------------------------------------
# 3. Generate SSH keys
# --------------------------------------------------

echo
echo "[3/7] Generating SSH keys..."

install -d -m 700 /root/.ssh

if [ ! -f /root/.ssh/admin_user_ed25519 ]; then
    ssh-keygen \
        -t ed25519 \
        -f /root/.ssh/admin_user_ed25519 \
        -N "" \
        -C "admin-user"
fi

if [ ! -f /root/.ssh/deploy_user_ed25519 ]; then
    ssh-keygen \
        -t ed25519 \
        -f /root/.ssh/deploy_user_ed25519 \
        -N "" \
        -C "deploy-user"
fi

# --------------------------------------------------
# 4. Configure authorized_keys
# --------------------------------------------------

echo
echo "[4/7] Configuring SSH authorized keys..."

for USER in "$ADMIN_USER" "$DEPLOY_USER"; do
    HOME_DIR="/home/$USER"

    install -d \
        -m 700 \
        -o "$USER" \
        -g "$USER" \
        "$HOME_DIR/.ssh"
done

install \
    -m 600 \
    -o "$ADMIN_USER" \
    -g "$ADMIN_USER" \
    /root/.ssh/admin_user_ed25519.pub \
    "/home/$ADMIN_USER/.ssh/authorized_keys"

install \
    -m 600 \
    -o "$DEPLOY_USER" \
    -g "$DEPLOY_USER" \
    /root/.ssh/deploy_user_ed25519.pub \
    "/home/$DEPLOY_USER/.ssh/authorized_keys"

# --------------------------------------------------
# 5. Configure SSH security
# --------------------------------------------------

echo
echo "[5/7] Configuring SSH security..."

cat > /etc/ssh/sshd_config.d/99-web-infrastructure.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF

sshd -t
systemctl restart ssh

# --------------------------------------------------
# 6. Configure firewall
# --------------------------------------------------

echo
echo "[6/7] Configuring firewall..."

ufw --force reset

ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow 22/tcp

# Web
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

# --------------------------------------------------
# 7. Configure environment and start containers
# --------------------------------------------------

echo
echo "[7/7] Starting Docker infrastructure..."

if [ ! -f "$PROJECT_DIR/.env" ]; then

    POSTGRES_PASSWORD="$(openssl rand -hex 24)"

    cat > "$PROJECT_DIR/.env" <<EOF
POSTGRES_DB=app_db
POSTGRES_USER=app_user
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REMOTE_SYSLOG_IP=syslog-receiver
EOF

    chmod 600 "$PROJECT_DIR/.env"

    echo ".env created."
else
    echo ".env already exists."
fi

docker compose down --remove-orphans

docker compose build

docker compose up -d

echo
echo "Waiting for services..."

sleep 10

docker compose ps

# --------------------------------------------------
# Final checks
# --------------------------------------------------

echo
echo "========================================"
echo " Deployment completed"
echo "========================================"

echo
echo "HTTP/HTTPS:"
echo "  https://localhost"

echo
echo "SSH users:"
echo "  $ADMIN_USER"
echo "  $DEPLOY_USER"

echo
echo "Generated private keys:"
echo "  /root/.ssh/admin_user_ed25519"
echo "  /root/.ssh/deploy_user_ed25519"

echo
echo "Test HTTPS:"
echo "  curl -k https://localhost"

echo
echo "Check containers:"
echo "  docker compose ps"

echo
echo "Check remote syslog:"
echo "  docker logs syslog-receiver --tail=20"

echo
echo "========================================"
