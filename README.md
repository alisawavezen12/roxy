# Roxy

Gleam monorepo с отдельными пакетами `frontend`, `backend` и `shared`. `shared` — локальная path dependency, а не отдельный runtime-сервис.

Требования: Docker Desktop с Docker Compose v2. Команды выполнять из корня проекта.

## DEV

DEV-окружение работает в фоне и управляется через Docker Desktop. После запуска терминал можно закрыть.

### Первый запуск

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build -d --wait
```

### Обычный ежедневный запуск

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --wait
```

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

Production frontend собирается официальной командой Lustre с `--minify` и запускается в non-root Nginx. Backend экспортируется через `gleam export erlang-shipment` и запускается в non-root Erlang runtime image без Gleam compiler, Bun, `watchexec` и исходников.

### Собрать production images

```sh
docker compose -f docker-compose.yml -f docker-compose.prod.yml build backend frontend
```

### Локально проверить production images

Для текущего foundation backend `DATABASE_URL` ещё не используется. После подключения PostgreSQL передавай настоящий production secret/config через environment или secrets mechanism.

```sh
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --wait backend frontend
```

Локальный production frontend: http://localhost:8081

Production backend не имеет секции `ports` и подключён только к изолированной сети `production_internal`. `expose: 8080` лишь документирует внутренний порт и само по себе не считается защитой. Frontend-контейнер проксирует `/api/` к backend внутри этой сети.

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
├── Dockerfile                 # production multi-stage build
├── docker-compose.yml         # PostgreSQL, MinIO и named volumes
├── docker-compose.dev.yml     # detached DEV frontend/backend
├── docker-compose.prod.yml    # production runtime frontend/backend
├── .dockerignore
├── backend/
│   └── Dockerfile.dev         # Gleam + watchexec
└── frontend/
    ├── Dockerfile.dev         # Gleam + system Bun + Lustre dev server
    └── nginx.conf             # production static frontend + API proxy
```
