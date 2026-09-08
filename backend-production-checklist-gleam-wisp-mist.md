# Production Backend Checklist — Gleam / Wisp / Mist / BEAM

Для проекта социальной сети / блога на Gleam с Wisp, Mist, PostgreSQL, S3-compatible storage, WebSocket, OTP и HAProxy.

Главный принцип: backend проектируется не как набор HTTP-роутов, а как маленький production-сервис на BEAM, где безопасное поведение является поведением по умолчанию, зависимости явные, процессы контролируются supervision tree, а любой внешний ресурс имеет timeout, лимит и понятный сценарий отказа.

---

## 1. Базовые архитектурные правила

- [ ] Backend разделён на слои, а не представляет собой набор HTTP handlers
- [ ] HTTP-слой не содержит SQL
- [ ] HTTP-слой не содержит бизнес-логику
- [ ] Бизнес-логика не знает о Wisp/Mist
- [ ] Работа с PostgreSQL скрыта за отдельными модулями/repository
- [ ] Работа с S3 скрыта за отдельным модулем
- [ ] Работа с SSO/OIDC скрыта за отдельным модулем
- [ ] Вебхуки имеют отдельный application/service layer
- [ ] WebSocket-логика отделена от обычного HTTP API
- [ ] Конфигурация читается централизованно
- [ ] Зависимости передаются явно, а не достаются из глобального состояния
- [ ] Нет захардкоженных URL, портов, secrets, bucket names и environment-specific значений
- [ ] Все внешние операции имеют timeout
- [ ] Для каждой операции заранее определено, какие ошибки она может вернуть

Базовая схема:

```text
HTTP / WebSocket
       ↓
   handlers
       ↓
 application/services
       ↓
    domain
       ↓
repositories / integrations
       ↓
PostgreSQL / S3 / SSO / Webhooks
```

То есть:

```text
route
  ↓
middleware
  ↓
handler
  ↓
service
  ↓
repository
```

А не:

```text
route
  ↓
SQL + S3 + auth + JSON + бизнес-логика
```

---

## 2. Структура приложения

Сразу договориться о структуре каталогов.

Пример:

```text
src/
  app.gleam
  config.gleam

  http/
    router.gleam
    middleware/
      auth.gleam
      request_id.gleam
      logging.gleam
      security.gleam
      error_handler.gleam
    handlers/
      posts.gleam
      users.gleam
      auth.gleam
      webhooks.gleam

  domain/
    user.gleam
    post.gleam
    comment.gleam
    reaction.gleam
    board.gleam

  services/
    post_service.gleam
    user_service.gleam
    webhook_service.gleam

  db/
    pool.gleam
    migrations.gleam
    repositories/
      posts.gleam
      users.gleam

  auth/
    oidc.gleam
    session.gleam

  storage/
    s3.gleam

  realtime/
    supervisor.gleam
    board_actor.gleam
    protocol.gleam

  jobs/
    supervisor.gleam
    webhook_delivery.gleam

  observability/
    logging.gleam
    metrics.gleam

  errors.gleam
```

Не обязательно именно такие названия. Важнее не позволить архитектуре постепенно превратиться в один `app.gleam` на несколько тысяч строк.

---

## 3. Startup / boot приложения

При старте backend должен пройти определённую последовательность.

- [ ] Прочитать конфигурацию
- [ ] Проверить обязательные переменные окружения
- [ ] Провалидировать значения конфигурации
- [ ] Проверить формат URL
- [ ] Проверить допустимость timeout'ов
- [ ] Проверить наличие secrets
- [ ] Инициализировать logging
- [ ] Создать PostgreSQL connection pool
- [ ] Проверить соединение с PostgreSQL
- [ ] Создать необходимые OTP actors
- [ ] Запустить supervisors
- [ ] Запустить HTTP server
- [ ] Только после успешной инициализации начать отвечать `ready`

Если обязательная конфигурация неправильная — fail fast.

```text
DATABASE_URL отсутствует
→ приложение не стартует

OIDC_CLIENT_SECRET отсутствует
→ приложение не стартует

S3 bucket не задан
→ либо приложение не стартует
→ либо storage feature явно выключена конфигом
```

Не делать production-critical fallback вроде:

```gleam
env.get("DATABASE_URL")
|> result.unwrap("localhost")
```

---

## 4. Конфигурация

Сделать один тип конфигурации:

```gleam
type Config {
  Config(
    database: DatabaseConfig,
    http: HttpConfig,
    auth: AuthConfig,
    storage: StorageConfig,
    webhook: WebhookConfig,
  )
}
```

- [ ] Один модуль отвечает за загрузку config
- [ ] Environment variables превращаются в типизированный `Config`
- [ ] Остальное приложение получает уже валидный `Config`
- [ ] Config не читается из environment посреди бизнес-логики
- [ ] Secrets не попадают в logs
- [ ] Для dev/test/prod используются одинаковые имена параметров
- [ ] Отличается значение, а не код

Хорошо:

```text
config.gleam
↓
Config
↓
весь backend
```

Плохо:

```text
posts.gleam → getenv()
auth.gleam → getenv()
storage.gleam → getenv()
router.gleam → getenv()
```

---

## 5. Supervision tree

Нарисовать supervision tree до того, как появятся фоновые процессы.

Пример:

```text
ApplicationSupervisor
│
├── DatabasePool
│
├── HttpServer
│
├── RealtimeSupervisor
│   ├── BoardRegistry
│   └── BoardDynamicSupervisor
│
├── JobSupervisor
│   └── WebhookDeliveryWorkers
│
└── Metrics/Telemetry
```

- [ ] Каждый долгоживущий процесс имеет owner
- [ ] Каждый критичный actor находится под supervisor
- [ ] Нет важных процессов, запущенных через бесконтрольный `spawn`
- [ ] Определена restart strategy
- [ ] Определено, какие процессы должны перезапускаться
- [ ] Определено, какие ошибки должны валить весь subsystem
- [ ] Ограничена restart intensity
- [ ] Crash loop не может бесконечно молотить CPU
- [ ] Actors используют links/monitors там, где необходимо
- [ ] При падении одного board actor не падают остальные boards

Главный принцип BEAM:

> Crash должен быть локальным.

Не:

```text
один WebSocket client сломал realtime subsystem
```

А:

```text
один WebSocket client process умер
→ supervisor/realtime продолжает работать
```

---

## 6. HTTP router

Router должен быть декларативным и скучным.

```text
router
├── /health
├── /ready
├── /auth/*
├── /api/*
└── /webhooks/*
```

- [ ] Все routes определяются централизованно
- [ ] Route не создаётся случайно внутри feature
- [ ] HTTP method указывается явно
- [ ] Неизвестный route → 404
- [ ] Неподдерживаемый method → 405
- [ ] API имеет понятный prefix
- [ ] Продумана стратегия версионирования API

Например:

```text
/api/v1/posts
/api/v1/users/:username
```

---

## 7. Middleware pipeline

Пример pipeline:

```text
Request
  ↓
Request ID
  ↓
Proxy / real IP handling
  ↓
Security headers
  ↓
Request size limits
  ↓
Logging
  ↓
Session parsing
  ↓
Authentication
  ↓
Authorization
  ↓
Rate limit
  ↓
Handler
  ↓
Error mapping
  ↓
Response logging
```

Часть middleware может различаться для public/internal/webhook endpoints.

---

## 8. Authentication: protected by default

Сделать архитектурным правилом:

```text
новый API route
↓
auth автоматически
```

И только явно:

```text
public_route(...)
```

Например:

```text
public:
GET /health
GET /ready
GET /auth/callback
POST /webhooks/incoming

authenticated:
всё остальное
```

Безопасность по принципу:

> Default deny.

- [ ] Все `/api/*` требуют session по умолчанию
- [ ] Public endpoints перечислены явно
- [ ] Отсутствие session → `401`
- [ ] Недостаточно permissions → `403`
- [ ] Handler получает уже типизированного authenticated user
- [ ] Handler не читает cookie самостоятельно
- [ ] Authorization проверяется отдельно от authentication

Authentication:

```text
"кто ты?"
```

Authorization:

```text
"можно ли тебе это делать?"
```

---

## 9. Сессии

Для OIDC + HttpOnly cookie:

- [ ] `HttpOnly`
- [ ] `Secure`
- [ ] Адекватный `SameSite`
- [ ] Случайный session ID
- [ ] Session rotation после login
- [ ] Session expiration
- [ ] Logout инвалидирует session
- [ ] Session ID нельзя логировать
- [ ] Access token SSO не отправляется frontend'у без необходимости
- [ ] Backend проверяет OIDC state
- [ ] Backend проверяет nonce, если используется
- [ ] Callback URL фиксирован/валидируется
- [ ] Защита от login CSRF
- [ ] Продумано обновление/истечение SSO session

---

## 10. Authorization

Не размазывать проверки прав по handlers.

Лучше иметь явные операции:

```text
can_delete_post
can_edit_board
can_view_board
can_manage_webhooks
```

- [ ] Права проверяются в application/domain layer
- [ ] Никогда не доверять `user_id`, пришедшему от клиента
- [ ] Owner определяется из authenticated context
- [ ] Для каждой mutation определён authorization rule

---

## 11. Request validation

Каждый input проходит:

```text
raw HTTP input
↓
parse
↓
validate
↓
typed command
↓
service
```

В service передавать не JSON object, а типизированную команду:

```text
CreatePost(
  text: String,
  ...
)
```

- [ ] Ограничение длины текста
- [ ] Ограничение username
- [ ] Ограничение количества изображений
- [ ] Ограничение размера body
- [ ] Проверка enum'ов
- [ ] Проверка UUID/id
- [ ] Нормализация там, где нужна
- [ ] Невалидные данные возвращают `400`
- [ ] Бизнес-ограничения возвращают нормальную domain error

---

## 12. Единая модель ошибок

Пример:

```gleam
type AppError {
  ValidationError(...)
  Unauthorized
  Forbidden
  NotFound
  Conflict(...)
  DatabaseError(...)
  ExternalServiceError(...)
  InternalError(...)
}
```

HTTP boundary:

```text
ValidationError → 400
Unauthorized    → 401
Forbidden       → 403
NotFound        → 404
Conflict        → 409
InternalError   → 500
```

- [ ] Handler не формирует произвольные error JSON
- [ ] Один error mapper
- [ ] Internal details не отдаются клиенту
- [ ] Stack trace/internal DB error не попадает в response
- [ ] Error имеет machine-readable `code`

Пример:

```json
{
  "error": {
    "code": "post_not_found",
    "message": "Post not found",
    "request_id": "..."
  }
}
```

---

## 13. PostgreSQL connection pool

Не один connection на приложение и не новый connection на каждый request.

Нужен pool:

```text
Backend instance
      ↓
PostgreSQL connection pool
      ↓
N постоянных connections
```

При нескольких backend-инстансах pool считается на весь cluster.

- [ ] Использовать pool
- [ ] Pool создаётся один раз при startup
- [ ] Pool передаётся repository
- [ ] Есть connect timeout
- [ ] Есть query timeout
- [ ] Есть pool checkout timeout
- [ ] Pool имеет ограниченный размер
- [ ] Connection возвращается в pool
- [ ] Broken connections восстанавливаются библиотекой/pool supervisor
- [ ] Нет connection leak

---

## 14. SQL

- [ ] Только parameterized queries
- [ ] Никогда не собирать SQL конкатенацией пользовательского input
- [ ] Явно указывать columns в `SELECT`
- [ ] Не использовать `SELECT *` в application queries
- [ ] Индексы проектируются вместе с запросами
- [ ] Foreign keys используются
- [ ] UNIQUE constraints используются
- [ ] NOT NULL используется там, где значение действительно обязательно
- [ ] DB constraints являются второй линией защиты после application validation

Если username уникален, должно быть не только приложение, но и:

```sql
UNIQUE(username)
```

---

## 15. Transactions

Транзакция должна соответствовать business operation.

Пример:

```text
create post
+
create attachment records
+
event/outbox
```

- [ ] Transaction boundary находится в service layer
- [ ] Repository не делает неожиданный commit
- [ ] Transaction максимально короткая
- [ ] Никаких HTTP/S3 вызовов внутри долгой DB transaction
- [ ] Ошибка → rollback
- [ ] Обработаны serialization/deadlock errors, если появятся

---

## 16. Миграции

- [ ] Все изменения schema выполняются миграциями
- [ ] Schema руками в production не редактируется
- [ ] Миграции хранятся в git
- [ ] Миграции имеют однозначный порядок
- [ ] Backend знает ожидаемую schema
- [ ] Есть отдельная команда migration
- [ ] Deployment strategy учитывает backwards-compatible migrations

Для production лучше:

```text
add new column
→ deploy compatible code
→ migrate data
→ remove old column позже
```

---

## 17. IDs

Заранее выбрать стратегию.

Подходящий вариант: UUID / UUIDv7 или аналогичный sortable identifier.

- [ ] ID генерируется server-side
- [ ] Клиент не выбирает `owner_id`
- [ ] IDs не являются security boundary
- [ ] Permission всё равно проверяется

---

## 18. Pagination

Не делать:

```text
GET /posts
→ вернуть все посты
```

Сразу:

```text
GET /posts?cursor=...
```

Для стены обычно лучше cursor pagination.

- [ ] Есть limit
- [ ] Есть максимальный limit
- [ ] Pagination стабильная
- [ ] Определён deterministic ordering
- [ ] На ordering есть подходящий index

---

## 19. Timeouts

Timeout должен существовать на каждой сетевой границе.

- [ ] PostgreSQL connect
- [ ] PostgreSQL query
- [ ] S3 request
- [ ] OIDC request
- [ ] Outgoing webhook
- [ ] Incoming HTTP body
- [ ] WebSocket inactivity
- [ ] HAProxy upstream
- [ ] Shutdown

---

## 20. Retries

Retry не является универсальным лечением ошибки.

Допустимо для:

```text
network timeout
503
connection reset
```

Не для:

```text
400
401
invalid payload
```

- [ ] Ограниченное количество retry
- [ ] Exponential backoff
- [ ] Jitter
- [ ] Максимальный возраст job
- [ ] Retry не создаёт duplicate operation

---

## 21. Idempotency

Особенно важно для webhooks.

Повторная доставка одного события должна приводить к одному результату.

- [ ] Incoming webhook имеет external event ID
- [ ] Event ID хранится
- [ ] UNIQUE constraint предотвращает duplicate processing
- [ ] Повторный webhook возвращает безопасный результат
- [ ] Outgoing deliveries имеют ID

---

## 22. Incoming webhook

Pipeline:

```text
request
↓
size limit
↓
signature/secret verification
↓
timestamp/replay validation
↓
JSON parsing
↓
schema validation
↓
idempotency check
↓
business transformation
↓
create Post
```

- [ ] Signature проверяется constant-time comparison
- [ ] Ограничен размер payload
- [ ] Проверяется timestamp
- [ ] Защита от replay
- [ ] Event ID используется для deduplication
- [ ] Unknown event types корректно обрабатываются
- [ ] Payload не логируется целиком, если содержит чувствительные данные

Если используется HMAC, raw body часто нужно проверять до JSON parsing.

---

## 23. Outgoing webhook

Не делать синхронный webhook в пользовательском HTTP request.

Лучше:

```text
HTTP request
↓
transaction
↓
создать событие/delivery
↓
commit
↓
response

background worker
↓
POST webhook
```

- [ ] Delivery хранится
- [ ] Status хранится
- [ ] Attempts хранятся
- [ ] Response code хранится
- [ ] Retry schedule хранится
- [ ] Timeout ограничен
- [ ] Redirect policy определена
- [ ] Есть SSRF-защита

Нельзя без проверки разрешать:

```text
http://localhost:...
http://127.0.0.1
http://169.254.169.254
внутренние Docker hostnames
private network ranges
```

---

## 24. Background jobs на OTP

Разделять два класса задач.

### Ephemeral

Можно потерять при reboot:

```text
transient telemetry task
```

### Durable

Нельзя потерять:

```text
outgoing webhook delivery
```

Durable job нельзя хранить только в actor mailbox.

Лучше:

```text
PostgreSQL
↓
pending delivery
↓
worker
↓
attempt
```

- [ ] Durable jobs записываются в DB
- [ ] Actor crash не теряет job
- [ ] Backend restart не теряет job
- [ ] Один job нельзя одновременно обработать дважды без защиты
- [ ] Есть max attempts
- [ ] Есть failed/dead state

---

## 25. ETS

Использовать как:

```text
cache
temporary presence
connection registry
ephemeral realtime state
```

Не как основную БД.

- [ ] PostgreSQL остаётся source of truth
- [ ] Данные ETS можно восстановить
- [ ] Определён owner ETS table
- [ ] Продумано, что происходит при падении owner process
- [ ] Размер ETS не растёт бесконечно
- [ ] Есть eviction/cleanup, если требуется

---

## 26. Actors и mailboxes

- [ ] Mailbox не может бесконтрольно расти
- [ ] Высокочастотные события не отправляются куда попало
- [ ] Есть backpressure/coalescing для cursor movement
- [ ] Не каждая мелочь требует отдельного actor
- [ ] Actor имеет понятного владельца и lifecycle
- [ ] Messages типизированы

Для Miro-like доски cursor events можно coalesce и оставлять только последнее положение.

---

## 27. WebSocket lifecycle

```text
connect
↓
authenticate
↓
authorize board
↓
subscribe
↓
send initial state
↓
process events
↓
heartbeat
↓
disconnect
↓
cleanup
```

- [ ] Authentication до подписки
- [ ] Authorization для board
- [ ] Max message size
- [ ] Rate limit
- [ ] Ping/pong/heartbeat
- [ ] Idle timeout
- [ ] Cleanup после disconnect
- [ ] Reconnect strategy
- [ ] Client может повторно синхронизировать state
- [ ] Сервер не предполагает идеальную доставку messages

---

## 28. Бинарный protocol

Сразу заложить header:

```text
version
message_type
message_id
payload
```

Например:

```text
| version | type | flags | length | payload |
```

- [ ] Protocol version
- [ ] Message type
- [ ] Length validation
- [ ] Unknown message type
- [ ] Unknown version
- [ ] Invalid payload
- [ ] Maximum payload
- [ ] Decoder никогда не доверяет клиенту
- [ ] Есть golden tests для binary encoding

---

## 29. S3 / MinIO

Хорошая схема:

```text
Frontend
↓
Backend просит upload permission
↓
Backend создаёт object key
↓
presigned URL
↓
Frontend → S3 напрямую
```

- [ ] Backend генерирует object key
- [ ] User не выбирает произвольный bucket/key
- [ ] Ограничен размер файла
- [ ] Ограничены content types
- [ ] Presigned URL короткоживущий
- [ ] Объект привязан к owner
- [ ] DB хранит metadata
- [ ] Удаление post корректно обрабатывает attachments
- [ ] Есть стратегия orphaned uploads

Не доверять только:

```text
Content-Type: image/png
```

---

## 30. Rate limiting

Минимум подумать о:

```text
login
user search
create post
comments
reactions
webhooks
uploads
WebSocket events
```

- [ ] Rate limit до тяжёлой работы
- [ ] Separate limits для дорогих endpoints
- [ ] Global/request-level защита
- [ ] Ограничение upload
- [ ] Ограничение WebSocket event rate

---

## 31. HTTP security

- [ ] TLS в production
- [ ] Security headers
- [ ] CORS строго настроен
- [ ] Не использовать `*` вместе с credentials
- [ ] CSRF model определена
- [ ] Cookie flags правильные
- [ ] Request body limit
- [ ] Header size limit
- [ ] Upload limit
- [ ] Никакого directory traversal
- [ ] Никакой передачи arbitrary filesystem paths
- [ ] SSRF protection
- [ ] SQL injection предотвращается parameters
- [ ] XSS учитывается на frontend/output boundary

---

## 32. HTTPS / TLS policy

Транспортная безопасность должна быть отдельным архитектурным инвариантом, а не необязательной production-настройкой.

Базовое правило проекта:

```text
Public HTTP      → HTTPS only
Public WebSocket → WSS only
Internal Docker  → HTTP/WS разрешён
Localhost dev    → HTTP/WS разрешён
```

Рекомендуемая production-схема:

```text
Internet
   │
   │ HTTPS / WSS
   ▼
HAProxy
   │
   │ HTTP / WS внутри trusted Docker network
   ▼
Gleam / Wisp / Mist
```

TLS завершается на HAProxy / reverse proxy. Сам Mist backend не обязан обслуживать TLS напрямую, если его порт недоступен из интернета и находится только во внутренней доверенной сети.

- [ ] В production публичный frontend/backend доступен только через `https://`
- [ ] Публичный WebSocket доступен только через `wss://`
- [ ] Backend-порт Mist не публикуется напрямую в интернет
- [ ] Незашифрованный public HTTP либо полностью отключён, либо делает redirect на HTTPS
- [ ] Для HTTP → HTTPS используется постоянный redirect (`308` либо осознанно выбранный аналог)
- [ ] После проверки HTTPS-конфигурации включён HSTS
- [ ] TLS-сертификаты автоматически обновляются
- [ ] Есть мониторинг истечения TLS-сертификата
- [ ] Production cookies имеют `Secure`
- [ ] Session cookies имеют `HttpOnly`
- [ ] Для cookies выбран подходящий `SameSite`
- [ ] Backend корректно определяет исходную схему запроса через trusted `X-Forwarded-Proto`
- [ ] `X-Forwarded-*` принимаются только от доверенного HAProxy / reverse proxy
- [ ] OIDC redirect/callback URL в production использует только `https://`
- [ ] Presigned S3 URLs в production используют HTTPS
- [ ] Incoming webhook production endpoints публикуются только через HTTPS
- [ ] Outgoing webhook URL по умолчанию обязан использовать HTTPS
- [ ] Исключение для HTTP допускается только для явно разрешённых localhost/dev сценариев
- [ ] Одного запрета HTTP для outgoing webhooks недостаточно — SSRF-защита всё равно обязательна
- [ ] Production config валидирует transport policy при startup
- [ ] Невалидная production transport-конфигурация приводит к fail-fast startup

Пример строгой config policy:

```text
development:
http://localhost:5173     ✅
http://localhost:8000     ✅
ws://localhost:8000       ✅

production:
https://example.com       ✅
wss://example.com/ws      ✅

http://example.com        ❌
ws://example.com/ws       ❌
```

Например:

```text
ENV=production
PUBLIC_URL=http://example.com
→ startup error
```

И аналогично для callback URL, публичного API URL и других внешних адресов.

Важно: слово **HTTP API** в архитектуре означает обычную HTTP-модель (`GET`, `POST`, headers, status codes, JSON), а не требование использовать незашифрованный `http://`.

---

## 33. Proxy trust

Поскольку перед backend будет HAProxy, нужно решить, кто имеет право устанавливать:

```text
X-Forwarded-For
X-Forwarded-Proto
```

- [ ] Backend доверяет forwarded headers только trusted proxy
- [ ] Client IP определяется корректно
- [ ] HTTPS detection работает за proxy
- [ ] WebSocket upgrade корректно проксируется

---

## 34. Health endpoints

Разделить:

```text
/health
/ready
```

### Liveness

```text
процесс вообще жив?
```

### Readiness

```text
можно ли сейчас слать ему traffic?
```

- [ ] `/health` работает отдельно
- [ ] `/ready` учитывает критичные startup dependencies
- [ ] HAProxy использует корректный health/readiness policy

---

## 35. Graceful shutdown

При SIGTERM:

```text
HAProxy перестаёт слать новые requests
↓
backend перестаёт принимать новые connections
↓
текущие requests заканчиваются
↓
WebSocket clients отключаются корректно
↓
workers прекращают брать новые jobs
↓
DB pool закрывается
↓
BEAM завершается
```

- [ ] SIGTERM обрабатывается
- [ ] Есть shutdown timeout
- [ ] Новые jobs не стартуют
- [ ] In-flight HTTP requests получают время закончиться
- [ ] Connections закрываются
- [ ] Deployment не обрывает запросы мгновенно

---

## 36. Structured logging

Не:

```text
"something went wrong"
```

А:

```json
{
  "level": "error",
  "event": "create_post_failed",
  "request_id": "...",
  "user_id": "...",
  "error": "database_timeout"
}
```

- [ ] JSON logs в production
- [ ] Log level
- [ ] Timestamp
- [ ] request_id
- [ ] route
- [ ] method
- [ ] response status
- [ ] duration
- [ ] error category
- [ ] Не логировать password/token/cookie/secret
- [ ] Не логировать чувствительный payload целиком

Пример использования `jq`:

```bash
docker logs backend |
jq 'select(.level == "error")'
```

---

## 37. Request ID / correlation ID

Каждый request:

```text
request_id = UUID
```

Дальше:

```text
HTTP
↓
logs
↓
service
↓
DB-related logs
↓
webhook delivery
```

Возвращать клиенту:

```text
X-Request-ID
```

---

## 38. Metrics

Минимальный набор:

```text
HTTP requests total
HTTP latency
HTTP errors
active connections
active WebSockets

DB pool usage
DB query latency

webhook deliveries
webhook retries
webhook failures

actor/process counts
mailbox lengths

memory
BEAM schedulers
```

Особенно интересно для BEAM:

```text
process count
mailbox size
reductions
memory
scheduler utilization
```

---

## 39. Observability rule

Для каждой subsystem ответить:

```text
Как я узнаю, что оно сломалось?

Как я пойму, почему оно сломалось?

Как я пойму, насколько сильно оно сломалось?
```

Например webhook:

```text
metric:
failed_delivery_count

log:
delivery_id + status + attempt

DB:
delivery history
```

---

## 40. Anonymous comments

Если требование звучит как:

> Даже сервер не должен иметь возможность установить автора.

Недостаточно сделать:

```sql
author_id = NULL
```

Потому что останутся:

```text
request logs
session logs
IP
request_id
timing
reverse proxy logs
```

- [ ] Определить, что именно означает «анонимно»
- [ ] Не хранить `author_id`
- [ ] Не связывать comment ID с user ID
- [ ] Проверить request logs
- [ ] Проверить HAProxy logs
- [ ] Не сохранять IP без необходимости
- [ ] Продумать abuse prevention без деанонимизации

---

## 41. Domain events

Можно мыслить событиями:

```text
PostCreated
PostDeleted
CommentCreated
ReactionAdded
BoardChanged
```

Не обязательно сразу строить event-driven architecture.

Пример:

```text
CreatePost
↓
DB transaction
↓
PostCreated
↓
schedule outgoing webhook
```

---

## 42. Outbox pattern

Для outgoing webhooks:

Проблема:

```text
INSERT post
COMMIT

CRASH

insert webhook job
```

Пост существует, webhook потерян.

Решение:

```text
BEGIN

INSERT post
INSERT outbox_event

COMMIT
```

Дальше worker читает outbox.

- [ ] Post и event записываются одной transaction
- [ ] Outbox processor работает отдельно
- [ ] Events имеют статус
- [ ] Повторная обработка безопасна

---

## 43. Dependency failures

Для каждой зависимости заранее определить поведение.

### PostgreSQL умер

```text
existing requests → controlled 5xx
health/readiness → backend unavailable
никаких бесконечных hangs
```

### S3 умер

```text
текстовые посты могут работать?
uploads → controlled error
```

### SSO умер

```text
existing sessions работают?
new login → unavailable
```

### Webhook endpoint клиента умер

```text
основной request не ломается
delivery retry later
```

Для каждого dependency должна существовать failure policy.

---

## 44. Backpressure

Нельзя позволять очередям расти бесконечно.

Лимиты нужны для:

```text
HTTP concurrency
DB pool
actor mailbox
background workers
WebSocket message rate
```

Лучше быстро отказать, чем накопить огромную очередь и упасть по памяти.

---

## 45. Data ownership

Для каждой сущности определить source of truth.

Пример:

```text
users          → PostgreSQL
posts          → PostgreSQL
comments       → PostgreSQL
attachments    → metadata PostgreSQL / bytes S3
board state    → PostgreSQL
board live     → actor/ETS cache
sessions       → зависит от реализации
webhook jobs   → PostgreSQL
```

---

## 46. Database constraints

Не полагаться только на код.

Пример:

```text
users.username
→ UNIQUE

posts.owner_id
→ FK users.id

comments.post_id
→ FK posts.id

reaction
→ UNIQUE(user_id, post_id, reaction)
```

- [ ] FK
- [ ] UNIQUE
- [ ] CHECK
- [ ] NOT NULL
- [ ] Appropriate `ON DELETE` behavior

---

## 47. Delete semantics

Для каждой сущности решить:

```text
hard delete
или
soft delete?
```

Для post может быть полезен:

```text
deleted_at
```

Но soft delete не нужно применять автоматически везде.

---

## 48. Timestamps

Обычно хранить:

```text
created_at
updated_at
```

в UTC.

- [ ] DB timestamps UTC
- [ ] Frontend отвечает за отображение timezone
- [ ] Не хранить локальное время пользователя как canonical timestamp

---

## 49. API response contract

Сразу договориться о формате:

```json
{
  "id": "...",
  "text": "...",
  "created_at": "..."
}
```

- [ ] Naming convention
- [ ] Date format
- [ ] ID format
- [ ] Nullability
- [ ] Error format
- [ ] Pagination format

---

## 50. Не возвращать DB model напрямую

Разделять:

```text
DatabasePost
DomainPost
PostResponse
```

Причина: в DB позже могут появиться internal fields, которые нельзя случайно отдать клиенту.

---

## 51. Testing pyramid

### Unit

```text
domain logic
validation
protocol encoding
permissions
```

### Integration

```text
real PostgreSQL
repository
migrations
transactions
```

### HTTP

```text
request
→ middleware
→ handler
→ DB
→ response
```

- [ ] Тест public route
- [ ] Тест protected route без auth
- [ ] Тест protected route с auth
- [ ] Тест чужого ресурса → 403
- [ ] Тест malformed input
- [ ] Тест DB constraint
- [ ] Тест webhook duplicate
- [ ] Тест webhook signature
- [ ] Тест binary protocol
- [ ] Тест WebSocket reconnect

---

## 52. Test database

Раздельно:

```text
development DB
test DB
production DB
```

- [ ] DB создаётся для tests
- [ ] migrations прогоняются
- [ ] test data изолирована
- [ ] тесты повторяемые

---

## 53. Docker

Backend container:

- [ ] Работает не от root
- [ ] Минимальный runtime image
- [ ] Build и runtime stages разделены
- [ ] Secrets не baked в image
- [ ] Config через environment/secrets
- [ ] Есть healthcheck
- [ ] Есть graceful shutdown
- [ ] Filesystem по возможности read-only
- [ ] Volumes только необходимые

---

## 54. Docker Compose

Для dev:

```text
frontend
backend
postgres
minio
haproxy позже
```

- [ ] Named volumes
- [ ] Healthchecks
- [ ] `depends_on` не используется как замена readiness
- [ ] Internal network
- [ ] PostgreSQL не обязательно торчит наружу
- [ ] MinIO admin port не открыт наружу в production
- [ ] Config вынесен

---

## 55. HAProxy

Когда будет два backend:

```text
            HAProxy
           /       \
    backend-1    backend-2
```

- [ ] Healthcheck
- [ ] Connect timeout
- [ ] Client timeout
- [ ] Server timeout
- [ ] WebSocket support
- [ ] Graceful backend removal
- [ ] Forwarded headers
- [ ] Request ID propagation
- [ ] Max connections
- [ ] Access logs

---

## 56. Stateless HTTP backend

Желательно:

```text
любой HTTP request
может попасть на любой backend instance
```

Не хранить session/важный state только в памяти конкретного instance, если это ломает распределение.

---

## 57. Realtime + несколько backend instances

Если:

```text
user A → backend-1
user B → backend-2
```

и оба смотрят одну board, понадобится межнодовое взаимодействие.

На первом этапе лучше:

```text
одна backend instance
→ правильная realtime abstraction
```

Позже:

```text
две instances
→ cluster problem
```

Не усложнять сразу WebSocket + actors + distributed systems.

---

## 58. Secrets

- [ ] Secrets не в git
- [ ] `.env` только для dev
- [ ] `.env` в `.gitignore`
- [ ] Production secrets через environment/secret store
- [ ] Secrets не логируются
- [ ] Secrets можно ротировать
- [ ] Webhook secrets уникальны

---

## 59. Admin/debug endpoints

Если появятся:

```text
/debug
/metrics
/admin
```

- [ ] Отдельная access policy
- [ ] Не публиковать internal diagnostics наружу
- [ ] Metrics endpoint закрыт сетью/auth

---

## 60. Feature flags

Экспериментальные вещи можно включать через config:

```text
FEATURE_BINARY_BOARD_PROTOCOL=true
```

Вместо логики вида:

```gleam
if environment == "production" { ... }
```

---

## 61. Что нельзя делать в request handler

Handler не должен:

- [ ] Писать SQL
- [ ] Создавать DB connection
- [ ] Читать env
- [ ] Делать authorization вручную, если это generic policy
- [ ] Содержать сложную бизнес-логику
- [ ] Бесконтрольно spawn'ить process
- [ ] Делать бесконечные retries
- [ ] Выполнять тяжёлую CPU-задачу
- [ ] Ждать webhook стороннего сервиса
- [ ] Доверять пользовательским IDs

Хороший handler:

```text
parse input
↓
call service
↓
map result
```

---

## 62. Что должно происходить при panic/crash

```text
handler crash
→ request → 500
→ request process умирает
→ server продолжает работать

background worker crash
→ supervisor restart
→ durable job остаётся в PostgreSQL

board actor crash
→ supervisor restart
→ state восстанавливается из source of truth

database connection crash
→ pool восстанавливает connection
```

Это нормальная BEAM-модель.

---

## 63. Production readiness checklist

Перед тем как считать backend готовым:

- [ ] Все routes имеют понятную auth policy
- [ ] Public production traffic доступен только через HTTPS/WSS
- [ ] HTTP/WS разрешён только внутри trusted network или для localhost/dev
- [ ] Production config запрещает `http://`/`ws://` для публичных URL и fail-fast при ошибке
- [ ] Backend-порт не доступен напрямую из интернета в обход reverse proxy
- [ ] HSTS и TLS certificate lifecycle настроены
- [ ] Public routes перечислены явно
- [ ] Все external calls имеют timeout
- [ ] Все retries ограничены
- [ ] DB использует pool
- [ ] Schema через migrations
- [ ] SQL parameterized
- [ ] Critical DB constraints существуют
- [ ] Transactions определены
- [ ] Graceful shutdown работает
- [ ] Health/readiness работают
- [ ] Structured logs есть
- [ ] Request ID есть
- [ ] Secrets не логируются
- [ ] Rate limits есть
- [ ] Body size limits есть
- [ ] Upload limits есть
- [ ] WebSocket limits есть
- [ ] Background jobs переживают restart
- [ ] Webhooks idempotent
- [ ] SSRF учтён
- [ ] Основные failure scenarios протестированы
- [ ] После падения одного actor приложение остаётся живым
- [ ] После падения PostgreSQL приложение деградирует контролируемо
- [ ] После возврата PostgreSQL приложение восстанавливается
- [ ] После SIGTERM текущие запросы не обрываются мгновенно

---

# Что заложить до первой нормальной feature

До `POST /posts` и `GET /posts`:

1. [ ] `Config` и строгая validation при startup
2. [ ] Корневой supervisor
3. [ ] PostgreSQL pool
4. [ ] `/health` и `/ready`
5. [ ] Центральный router
6. [ ] Auth-required-by-default для `/api`
7. [ ] Явный механизм `public route`
8. [ ] `request_id`
9. [ ] Structured JSON logging
10. [ ] Единый `AppError`
11. [ ] Единый HTTP error mapper
12. [ ] Request/body limits
13. [ ] Graceful shutdown
14. [ ] Migration system
15. [ ] Разделение `handler → service → repository`
16. [ ] HTTPS/localhost transport policy в config validation (`https://`/`wss://` в production, HTTP/WS только localhost/dev или internal network)

После этого первая вертикальная фича сразу проходит через production-like архитектуру.

---

# Рекомендуемый дополнительный этап roadmap

## Этап 2.5. Backend foundation

Цель — заложить инфраструктурный фундамент до первой реальной бизнес-фичи.

- [ ] Типизированный config
- [ ] Validation config при startup
- [ ] Fail-fast boot
- [ ] Корневой supervisor
- [ ] Supervision tree
- [ ] PostgreSQL connection pool
- [ ] Центральный router
- [ ] Middleware pipeline
- [ ] Auth required by default
- [ ] Явный public route mechanism
- [ ] Request ID
- [ ] Structured JSON logging
- [ ] Единая модель ошибок
- [ ] HTTP error mapper
- [ ] Request/body limits
- [ ] `/health`
- [ ] `/ready`
- [ ] Migration system
- [ ] Graceful shutdown
- [ ] Базовая observability
- [ ] Разделение `handler → service → repository`
- [ ] HTTPS/WSS production policy и localhost-only HTTP/WS exception
- [ ] TLS termination policy на HAProxy / reverse proxy

**Результат:** первая бизнес-фича строится уже поверх production-like backend foundation, без временной архитектуры и последующего переписывания.
