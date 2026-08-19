# Web Infrastructure Deployment

## Requirements

* Ubuntu Server 24.04 LTS
* Docker
* Docker Compose v2
* Git

## 1. Clone repository

```bash
git clone <REPOSITORY_URL>
cd web_infrastructure_deployment
```

## 2. Set SSH public keys

```bash
export ADMIN_PUBLIC_KEY="ssh-ed25519 AAAA..."
export DEPLOY_PUBLIC_KEY="ssh-ed25519 BBBB..."
```

## 3. Run setup

```bash
sudo ./setup.sh
```

The script configures:

* `admin-user` and `deploy-user`
* SSH key authentication
* disables SSH password authentication
* disables root SSH login
* configures UFW
* starts the Docker infrastructure

## 4. Check containers

```bash
docker compose ps
```

All containers should be running and healthy where healthchecks are configured.

## 5. Check HTTPS

```bash
curl -k https://localhost
```

Expected:

```text
PHP → PostgreSQL connection: OK
Database: app_db
User: app_user
```

## 6. Check remote syslog

```bash
docker logs syslog-receiver --tail=20
```

Nginx access logs should be visible in the output.

## 7. Check rsyslog queue

```bash
docker exec rsyslog ls -lah /var/spool/rsyslog
```

When the remote syslog receiver is unavailable, queued messages should appear in this directory.

## Stop

```bash
docker compose down
```

