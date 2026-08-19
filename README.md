# Web Infrastructure Deployment

## Запуск

```bash
git clone <REPOSITORY_URL>
cd web_infrastructure_deployment
sudo ./setup.sh
```

## Проверка

```bash
docker compose ps
curl -k https://localhost
docker logs syslog-receiver --tail=20
```

## Ожидаемый результат

```text
PHP → PostgreSQL connection: OK
Database: app_db
User: app_user
```

Все настройки SSH, пользователей, UFW и Docker выполняются автоматически через `setup.sh`.

## Остановка

```bash
docker compose down
```

