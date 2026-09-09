# Backend foundation — актуальный статус

Этот документ фиксирует состояние foundation-слоя backend-а перед первой бизнес-фичей.

Он не является общим production-roadmap. Постоянные требования безопасности и эксплуатации находятся в:

```text
../backend-production-checklist-gleam-wisp-mist.md
```

В частности, secure-by-default правила, TLS/WSS, production proxy, rate limiting, migrations, resource authorization и deployment hardening не дублируются здесь.

---

## Границы foundation

Foundation сейчас включает:

- Mist и Wisp;
- typed configuration и fail-fast startup;
- явные application dependencies;
- OTP supervision tree;
- HTTP transport boundary;
- WebSocket handshake и connection boundary;
- access policy и session verification;
- HTTP/WebSocket error mappings;
- request ID и базовое техническое логирование;
- PostgreSQL connection pool через `pog`;
- базовые body/file limits;
- тестовый foundation для HTTP, WebSocket, access и OTP.

Не является частью текущего foundation:

- бизнес-сущности и repositories;
- migrations и test database;
- resource-level authorization;

- SSO/OIDC и полноценная session lifecycle model;
- rate limiting;
- S3, webhooks, jobs, ETS и distributed realtime;
- публичный TLS termination через HAProxy/reverse proxy.

Эти требования описаны в production checklist или добавляются вместе с соответствующей feature.

---

## 0. Точка старта и актуальная структура

- [x] Сохранён Gleam backend project.
- [x] Удалена старая HTTP-структура и старые тестовые модули.
- [x] Оставлена минимальная точка входа `src/backend.gleam`.
- [x] Рабочая структура отражает ownership слоёв.
- [x] Foundation проверяется через `gleam check` и `gleam test`.

Текущее дерево рабочих модулей:

```text
backend/src
├── application
│   ├── access.gleam
│   ├── dependencies.gleam
│   └── services/session.gleam
├── config
├── db
├── domain              # бизнес-домен пока пуст
├── jobs                # зарезервировано для будущих jobs
├── observability
├── storage             # зарезервировано для будущего storage
├── transport
│   ├── dispatcher.gleam
│   ├── session.gleam
│   ├── transport_context.gleam
│   ├── http
│   │   ├── handlers
│   │   ├── middleware
│   │   ├── protocol
│   │   ├── request_id.gleam
│   │   └── router.gleam
│   └── websocket
│       ├── connection
│       ├── handlers
│       ├── handshake
│       ├── protocol
│       └── router.gleam
└── roxy_application.gleam
```

Слои не смешиваются:

```text
transport → application → domain

config / db / storage / jobs / observability
```

`application/access.gleam` содержит общую access policy (`Principal`, permissions, `authorize`), а не HTTP/WebSocket response logic.

---

## 1. Локальное окружение

- [x] Docker Compose для development существует.
- [x] Development явно задаёт `APP_ENV=development`.
- [x] Production Compose явно задаёт `APP_ENV=production`.
- [x] Backend запускается в контейнере вместе с PostgreSQL.

---

## 2. Mist и Wisp

- [x] Mist используется как HTTP server.
- [x] Wisp используется как HTTP web layer.
- [x] Startup отделён от request handling.
- [x] `/health` отвечает через production router.
- [x] Неизвестный HTTP route возвращает `404`.
- [x] Resource существует, но method не разрешён — возвращается `405` с `Allow`.
- [x] `HEAD` использует тот же route и access policy, что и соответствующий `GET`.
- [x] WebSocket `/ws` проходит через dispatcher и отдельный handshake pipeline.

---

## 3. Конфигурация

- [x] Конфигурация собирается до запуска зависимостей и server.
- [x] `AppConfig` содержит environment, host, port, secret, origins и PostgreSQL config.
- [x] Production settings обязательны.
- [x] Port валидируется до startup.
- [x] `APP_ENV` обязателен; отсутствие или пустое значение не включает Development автоматически.
- [x] Development defaults ограничены development environment.
- [x] Secrets не читаются из handler/service и не логируются.
- [x] CORS origins валидируются как конкретные HTTP origins.

---

## 4. Application dependencies

- [x] Существует typed `Dependencies`.
- [x] Config и PostgreSQL connection передаются явно.
- [x] Dependencies создаются один раз на startup.
- [x] Handlers и transport routers не создают DB connections.
- [x] Handler/service не читают environment напрямую.
- [x] Глобальный mutable dependency container не используется.

Схема:

```text
startup
  ↓
Config
  ↓
Dependencies
  ↓
transport router
  ↓
application service
  ↓
repository / infrastructure
```

---

## 5. OTP supervision и startup

- [x] Есть главный startup `roxy_application.start`.
- [x] PostgreSQL pool добавляется в supervision tree.
- [x] HTTP server запускается через `mist.supervised`.
- [x] Используется `RestForOne`, потому что HTTP зависит от DB startup.
- [x] Настроена restart tolerance root supervisor.
- [x] Поведение падения supervised child покрыто OTP tests.
- [x] Процесс entrypoint остаётся живым после запуска supervision tree.

Graceful shutdown и deployment-level drain policy относятся к production checklist и требуют отдельной runtime/integration проверки.

---

## 6. HTTP pipeline

Текущий HTTP pipeline:

```text
request
  ↓
TransportContext / request_id
  ↓
body/file limits
  ↓
HTTP logging
  ↓
CORS
  ↓
safe crash boundary
  ↓
HEAD handling
  ↓
route lookup
  ↓
explicit method check
  ↓
session extraction
  ↓
access policy
  ↓
route body contract
  ↓
handler
  ↓
HTTP error/response mapping
  ↓
X-Request-ID
```

- [x] Каждый HTTP route имеет обязательные `methods`, `access`, `body` и handler.
- [x] `Public` не является default policy.
- [x] Unknown route не становится public fallback.
- [x] HTTP body и file limits настраиваются до router/business logic.
- [x] Content-Type проверяется только для `Json` и `Multipart` routes.
- [x] Media type сравнивается строго, с поддержкой parameters вроде `charset`.
- [x] Unsupported content type маппится в `415`.
- [x] HTTP errors используют `HttpError` и единый JSON renderer.
- [x] Crash response не раскрывает stack trace.
- [x] Тестовый crash route существует только в test fixture.

Ограничение текущего этапа: production routes пока используют `NoBody`, поэтому полноценный JSON parsing и фактический body-read `413` будут проверены вместе с первой body feature.

---

## 7. WebSocket pipeline

```text
request
  ↓
explicit route lookup
  ↓
explicit method check
  ↓
Origin validation
  ↓
Upgrade header validation
  ↓
session extraction
  ↓
access policy
  ↓
handshake response или upgrade
  ↓
connection lifecycle
  ↓
message protocol handling
```

- [x] WebSocket route имеет обязательные `methods`, `access` и handler.
- [x] Origin проверяется до upgrade.
- [x] Upgrade, Connection, Sec-WebSocket-Key и version проверяются до upgrade.
- [x] Authentication/access policy выполняется до `mist.websocket`.
- [x] WebSocket handshake errors отделены от established protocol errors.
- [x] Handshake `405` возвращает `Allow`.
- [x] Handshake получает request ID.
- [x] Handshake completion log содержит method, path, status, duration и request ID.
- [x] Oversized message закрывает конкретное соединение и логируется.

Ограничение: message size проверяется в application callback после передачи сообщения Mist. Transport-level pre-allocation limit нужно проверить и настроить отдельно, если это поддерживается текущей версией Mist.

---

## 8. Access и session

- [x] Общая access policy находится в `application/access.gleam`.
- [x] Внутренние ошибки policy называются `Unauthenticated` и `Forbidden`.
- [x] HTTP и WebSocket используют один `AccessError`, но разные boundary mappings.
- [x] Cookie/header parsing находится в `transport/session.gleam`.
- [x] Signed session verification находится в `application/services/session.gleam`.
- [x] Missing session и invalid session не раскрываются клиенту.
- [x] В логах различаются `session_missing` и `session_invalid` без записи token/cookie.
- [x] Protected-by-default правило зафиксировано для новых API routes.

Полноценные expiration, revocation, logout и OIDC lifecycle относятся к production/auth roadmap.

---

## 9. Error ownership

Единого глобального `AppError` для всех уровней нет и не создаётся.

- [x] HTTP errors находятся в `transport/http/protocol/http_errors.gleam`.
- [x] WebSocket handshake errors находятся в `transport/websocket/handshake/validation.gleam`.
- [x] Established WebSocket failures остаются в WebSocket protocol/handler ownership.
- [x] Access errors имеют одно каноническое место в `application/access.gleam`.
- [x] HTTP и WebSocket выполняют отдельные boundary mappings.
- [x] Ошибки с одинаковым внешним status не объединяются без общей причины.
- [x] HTTP `PayloadTooLarge` не объединён с WebSocket `MessageTooLarge`.
- [x] Stack trace и internal details не возвращаются клиенту.

---

## 10. Request ID и logging

- [x] Request ID генерируется сервером.
- [x] Входящий `X-Request-ID` не принимается как authoritative value.
- [x] HTTP responses, включая errors, содержат `X-Request-ID`.
- [x] WebSocket handshake response содержит request ID.
- [x] HTTP logs содержат timestamp, event, transport, request_id, method, path, status и duration.
- [x] WebSocket handshake и connection logs содержат request_id.
- [x] Body, cookies, tokens, authorization headers и secrets не логируются.
- [x] Invalid session причины логируются без sensitive values.

---

## 11. PostgreSQL pool

- [x] PostgreSQL config загружается отдельно.
- [x] `pog` pool создаётся на startup.
- [x] Pool находится под supervision.
- [x] Pool size конечный.
- [x] Query timeout применяется к DB operations.
- [x] Поведение pool exhaustion покрыто integration test при наличии PostgreSQL.
- [x] Бизнес-таблицы, repositories и migrations до первой feature не создавались.

---

## 12. Тестовая проверка foundation

- [x] Access policy tests.
- [x] HTTP route/error mapping tests.
- [x] HTTP integration tests для `404`, `405`, `HEAD`, CORS и crash behavior.
- [x] WebSocket handshake validation/mapping tests.
- [x] WebSocket integration tests для successful connection, forbidden origin, invalid method, malformed handshake и oversized message.
- [x] OTP supervision tests.
- [x] Configuration validation tests.
- [x] `gleam format --check` проходит.
- [x] `gleam check` проходит.
- [x] `gleam test` проходит: текущий результат — `56 passed, no failures`.

---

## Что не является завершённым foundation и переносится дальше

`/health` — liveness endpoint, а `/ready` — readiness endpoint, который проверяет PostgreSQL через pool и возвращает `503`, если зависимость недоступна. Readiness входит в foundation и реализован.

Следующие пункты не считаются забытыми или «случайно не отмеченными». Они намеренно вынесены из foundation scope:

- SQL migrations и отдельная test database;
- первая domain/business feature;
- repositories и resource-level authorization;
- полноценный JSON/multipart body parsing;
- session expiration/revocation/logout/OIDC;
- rate limiting и security headers;
- TLS/WSS termination и reverse proxy hardening;
- production graceful drain;
- metrics и полноценная production observability;
- S3, jobs, webhooks, ETS, distributed realtime.

Правила для этих задач находятся в production checklist и должны выполняться вместе с соответствующей feature, а не добавляться заранее пустыми модулями.

---

## Следующий этап

Первая бизнес-фича должна пройти вертикальный путь:

```text
migration
  ↓
domain
  ↓
repository
  ↓
application service
  ↓
HTTP handler
  ↓
route with explicit methods/access/body contract
  ↓
resource-level authorization
  ↓
integration tests
```

Mutation route нельзя делать public «временно». Он должен быть `Authenticated` или `Permission(...)`, либо явно ограничен development-only policy, недоступной в production.
