# Web Infrastructure Deployment

## Run

```bash
git clone <REPOSITORY_URL>
cd web_infrastructure_deployment

docker compose up -d --build
```

## Check

```bash
docker compose ps
curl -k https://localhost
```

## Check logs

```bash
docker logs syslog-receiver --tail=20
```

## Stop

```bash
docker compose down
