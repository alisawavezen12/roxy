# Roxy

Gleam monorepo с отдельными пакетами `frontend`, `backend` и `shared`. `shared` — локальная path dependency, а не отдельный runtime-сервис.

Требования: Docker Desktop с Docker Compose v2. Команды выполнять из корня проекта.

## DEV

DEV-окружение работает в фоне и управляется через Docker Desktop. После запуска терминал можно закрыть.

### Первый запуск

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build --force-recreate -d --wait
```

### Обычный ежедневный запуск

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
```

### SQL migrations

Применить все ещё не выполненные SQL migrations через существующий PostgreSQL/pog setup:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml run --rm backend gleam run -m backend_migrations
```

Migrations хранятся в `backend/migrations/`, именуются вроде `0001_create_posts.sql` и не запускаются автоматически при старте backend.

### Dobrunia Auth SSO

Backend реализует OAuth 2.0 Authorization Code flow. Зарегистрируйте callback URL `http://localhost:8080/auth/sso/callback` для DEV или `{PUBLIC_BASE_URL}/auth/sso/callback` для production и задайте:

```env
DOBRUNIA_AUTH_CLIENT_ID=your-client-slug-or-uuid
# Отдельный секрет шифрования токенов, минимум 32 символа
AUTH_TOKEN_ENCRYPTION_KEY=replace-with-a-random-secret
```

Начало входа: `GET /auth/sso`. Callback обрабатывается backend. Dobrunia-токены не выдаются браузеру: они хранятся в PostgreSQL с AES-256-GCM, а клиент получает только `HttpOnly` cookie локальной Roxy-сессии. Ротация внешнего refresh token выполняется через `POST /auth/sso/refresh`, а выход из обеих сессий — через `POST /auth/sso/logout`. Оба endpoint используют credentialed cookie и защищены origin-проверкой.

### Backend-тесты с PostgreSQL

Запустить полный backend test suite внутри development-контейнера, включая integration-тест pool:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml run --rm backend gleam test
```

Тесты выполняются внутри Docker-сети, поэтому backend обращается к PostgreSQL по внутреннему имени сервиса `postgres`. Integration-сценарий запускается только при `APP_ENV=development`.

### Что обновляется автоматически

| Изменение | Действие |
|---|---|
| `backend/src/**/*.gleam` | `watchexec` перезапускает `gleam run` внутри существующего backend-контейнера |
| `frontend/src/**/*.gleam` | container watcher перезапускает официальный Lustre dev server; браузер подключается заново |
| `frontend/assets/**` | container watcher перезапускает официальный Lustre dev server |
| `shared/src/**/*.gleam` | frontend и backend перезапускают dev workflow и выполняют incremental Gleam rebuild |
| `backend/gleam.toml`, `backend/manifest.toml` | требуется rebuild только backend image |
| `frontend/gleam.toml`, `frontend/manifest.toml` | требуется rebuild только frontend image |
| `shared/gleam.toml`, `shared/manifest.toml` | требуется rebuild frontend и backend images |
| данные PostgreSQL или MinIO | image rebuild не выполняется |

Исходники подключены через bind mounts. `build/`, `dist/`, `.lustre/`, dependency cache и Bun cache остаются внутри Linux filesystem контейнеров и не создают volumes на хосте.

### Rebuild только backend

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build --no-deps -d backend
```

### Rebuild только frontend

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build --no-deps -d frontend
```

### Rebuild после изменения shared dependencies

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build --no-deps -d backend frontend
```

### Адреса

- frontend: http://localhost:1234
- backend: http://localhost:8080
- MinIO API: http://localhost:9000
- MinIO Console: http://localhost:9001
- PostgreSQL (DEV only): `127.0.0.1:5433`

Для подключения через pgAdmin и описания таблиц см. [`backend/docs/database.md`](backend/docs/database.md).

Создать локальный bucket `roxy` при первом подключении файлового хранилища:

```sh
docker compose -f docker-compose.yml --profile setup run --rm minio-init
```

`minio-init` — одноразовая setup-задача и не запускается при обычном DEV `up`.

### Логи

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend frontend
```

### Process tree

```text
backend container
└── Docker init (PID 1)
    └── watchexec (polling Windows bind mounts)
        └── gleam run
            └── BEAM / Mist / Wisp

frontend container
└── Docker init (PID 1)
    └── watchexec (polling Windows bind mounts)
        └── gleam run -m lustre/dev start
            ├── официальный Lustre dev server/watcher
            ├── system Bun
            └── browser reload
```

`init: true` пересылает сигналы и собирает завершившиеся дочерние процессы. `watchexec --restart` управляет process group каждого приложения. При Stop через Docker Desktop watcher-ы и приложения завершаются вместе с контейнерами.

На Windows Bun `Fs.watch`, используемый Lustre, не всегда получает события от bind mount. Поэтому внешний `watchexec --poll` внутри frontend-контейнера перезапускает официальный Lustre dev server. На хосте отдельный watcher не работает.

## Управление DEV

### Просто остановить

Контейнеры сохраняются и могут быть снова запущены через Docker Desktop:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml stop
```

### Удалить контейнеры и сеть, сохранить данные

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
```

### Полностью удалить dev-данные

Осторожно: команда удаляет PostgreSQL и MinIO data volumes этого проекта.

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v
```

Автоматический агрессивный Docker prune не используется. Build cache полезен и ускоряет последующие сборки.

## PRODUCTION

Frontend и backend — два независимых production deployment-а:

- frontend собирается в статические файлы Lustre и может быть загружен на отдельный hosting/CDN;
- backend собирается в Erlang shipment и запускается отдельно вместе с БД, storage и jobs;
- frontend не проксирует `/api` через Docker. В production URL backend вшивается в frontend при сборке через `API_ORIGIN`;
- `CORS_ALLOWED_ORIGINS` на backend должен содержать точный origin frontend (например, `https://app.example.com`, без `/` в конце).

### Собрать production frontend

```sh
docker compose -f docker-compose.frontend.prod.yml build --build-arg API_ORIGIN=https://api.example.com frontend
```

Локальная проверка production frontend:

```sh
docker compose -f docker-compose.frontend.prod.yml up -d --wait frontend
```

Frontend будет доступен на http://localhost:8081. Для реального frontend hosting можно использовать тот же `API_ORIGIN` и загрузить содержимое `/usr/share/nginx/html` из образа либо выполнить сборку frontend вне Docker.

### Собрать production backend stack

```sh
docker compose -f docker-compose.yml -f docker-compose.prod.yml build backend
```

Запуск локального backend stack с PostgreSQL:

```sh
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --wait backend postgres
```

Production backend слушает localhost:8080 в локальной проверке. На реальном сервере его нужно подключить к HTTPS reverse proxy/load balancer, который будет публиковать API origin. PostgreSQL и MinIO в production Compose предназначены для local-infra проверки; настоящий production должен получать DB и S3 через runtime config/secrets.

### Production traffic policy

```text
Internet
  ↓
HTTPS / WSS
  ↓
HAProxy или другой reverse proxy
  ↓
HTTP / WS внутри trusted Docker network
  ↓
backend:8080
```

HAProxy будет добавлен на отдельном этапе. Публичный доступ к Mist в обход reverse proxy не предполагается. PostgreSQL, MinIO и `minio-init` в production Compose находятся за профилем `local-infra` и по умолчанию не запускаются. Этот профиль предназначен только для локальной production-like проверки; настоящий production должен получать DB и S3 через runtime config/secrets.

## Где находятся данные

### Persistent

Named volumes создаются только для реальных данных:

- `roxy_postgres_data` — PostgreSQL;
- `roxy_minio_data` — MinIO.

Обычный `docker compose down` их сохраняет.

### Disposable

Следующие данные находятся в writable layer контейнера или Docker build cache:

- Gleam `build/`;
- Lustre `.lustre/` и `dist/`;
- скачанные Gleam dependencies;
- Bun cache;
- скомпилированные BEAM/JavaScript-файлы DEV.

Они не bind-mount-ятся на Windows и могут быть восстановлены сборкой.

## Docker-файлы

```text
roxy/
├── docker-compose.frontend.prod.yml # отдельный production frontend
├── docker-compose.yml         # PostgreSQL, MinIO и named volumes
├── docker-compose.dev.yml     # detached DEV frontend/backend
├── docker-compose.prod.yml    # production backend + local DB
├── .dockerignore
├── backend/
│   ├── Dockerfile.dev         # Gleam + watchexec
│   └── Dockerfile.prod        # Erlang shipment runtime
└── frontend/
    ├── Dockerfile.dev         # Gleam + system Bun + Lustre dev server
    ├── Dockerfile.prod        # standalone static frontend image
    └── nginx.conf             # static frontend runtime
```
