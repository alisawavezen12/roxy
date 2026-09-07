# Roxy

Нужен запущенный Docker с Compose v2. Команды выполнять из корня проекта.

Запуск:

```sh
docker compose --profile stack up --build -d
```

Приложение: http://localhost:8080.

Остановка с сохранением данных:

```sh
docker compose --profile stack down
```

Конфигурация предназначена только для локальной разработки.
