# Roxy

Нужен запущенный Docker с Compose v2. Команды выполнять из корня проекта.

Запуск:

```sh
docker compose --profile stack up --build -d
```

Приложение: http://localhost:8080

Остановка с сохранением данных:

```sh
docker compose --profile stack down
```

Конфигурация предназначена только для локальной разработки.

## Архитектура

Проект организован как монорепозиторий: сервер, клиент и общий Gleam-пакет находятся в отдельных директориях, а локальная инфраструктура запускается через Docker Compose.

### Структура проекта

```text
roxy/
├── backend/       HTTP API и серверная часть на Gleam/Erlang
├── frontend/      Клиентское приложение на Gleam/JavaScript и Lustre
├── shared/        Общие типы и код для frontend и backend
├── db/            Инициализация PostgreSQL
├── scripts/       Вспомогательные shell-скрипты
├── Dockerfile     Сборка frontend и backend в production-образ
└── docker-compose.yml
```
