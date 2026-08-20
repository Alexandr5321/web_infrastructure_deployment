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
echo "[1/8] Installing required packages..."

apt-get update
apt-get install -y \
    docker.io \
    docker-compose-v2 \
    openssh-server \
    openssl \
    ufw

systemctl enable --now docker
systemctl enable --now ssh

# --------------------------------------------------
# 2. Create users
# --------------------------------------------------

echo
echo "[2/8] Creating users..."

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
echo "[3/8] Generating SSH keys..."

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
echo "[4/8] Configuring SSH authorized keys..."

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
echo "[5/8] Configuring SSH security..."

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
echo "[6/8] Configuring firewall..."

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
# 7. Configure environment and SSL certificates
# --------------------------------------------------

echo
echo "[7/8] Configuring environment and SSL certificates..."

# Create .env if it doesn't exist
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

# Create SSL directory
mkdir -p "$PROJECT_DIR/nginx/ssl"

# Generate self-signed certificate if it doesn't exist
if [ ! -f "$PROJECT_DIR/nginx/ssl/fullchain.pem" ] || \
   [ ! -f "$PROJECT_DIR/nginx/ssl/privkey.pem" ]; then

    echo "Generating self-signed SSL certificate..."

    openssl req -x509 \
        -nodes \
        -days 365 \
        -newkey rsa:2048 \
        -keyout "$PROJECT_DIR/nginx/ssl/privkey.pem" \
        -out "$PROJECT_DIR/nginx/ssl/fullchain.pem" \
        -subj "/C=GE/ST=Tbilisi/L=Tbilisi/O=WebInfrastructure/CN=localhost"

    chmod 600 "$PROJECT_DIR/nginx/ssl/privkey.pem"
    chmod 644 "$PROJECT_DIR/nginx/ssl/fullchain.pem"

    echo "SSL certificate generated."
else
    echo "SSL certificates already exist."
fi

# --------------------------------------------------
# 8. Start Docker infrastructure
# --------------------------------------------------

echo
echo "[8/8] Starting Docker infrastructure..."

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
echo "SSL certificates:"
echo "  $PROJECT_DIR/nginx/ssl/fullchain.pem"
echo "  $PROJECT_DIR/nginx/ssl/privkey.pem"

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
