# Backend foundation audit

Дата аудита: 2026-09-12

Область проверки: `backend/`, связанная production/development container-конфигурация и общий API error contract в `shared/`.

Цель: оценить backend как переиспользуемый каркас перед началом реализации бизнес-фичей. Отличия от предполагаемой архитектуры не считались дефектами, если текущая реализация сохраняет понятный ownership, безопасное направление зависимостей и простую композицию.

## Executive summary

Каркас имеет хорошую основу: transport отделён от application/config/database, domain-инфраструктурного coupling нет, routes декларативно содержат methods/body/access policy, production config fail-fast, PostgreSQL pool и OTP children имеют единственного owner, миграции транзакционны, Wisp/Mist/pog используются через актуальные публичные API.

При этом foundation пока нельзя считать полностью готовым к бизнес-фичам. Основные блокирующие причины:

1. WebSocket message limit применяется после полной буферизации, сборки фрагментов и decompression внутри Mist/Gramps. Текущий публичный `/ws` поэтому не имеет ранней защиты от больших/сжатых сообщений.
2. HTTP limiter использует непосредственный IP reverse proxy как client identity и fail-open при невозможности получить peer metadata.
3. WebSocket connection reservation может утечь, если `mist.websocket` не завершит upgrade/start процесса.
4. Ошибка или timeout limiter actor находится вне единого application safety boundary и может вернуть клиенту сырой Mist `500` без обычного error contract и корреляции.
5. Production artifact не содержит `migrations/` и не предоставляет production migration step, хотя runtime зависит от schema `sessions`.

Остальные findings не блокируют разработку первой business entity, но должны быть исправлены в foundation, чтобы не закрепить небезопасный контракт в новых routes.

---

## 1. Архитектура и ownership

**Status: OK**

### Current approach

- `src/application/` владеет access semantics, dependency container и session service.
- `src/config/` централизованно загружает application, environment, origin, session и transport config.
- `src/db/` владеет PostgreSQL config, pool и migration runner.
- `src/transport/http/` и `src/transport/websocket/` являются отдельными transport boundaries.
- Общие для transport концепции находятся в `src/transport/`: session adapter, context, protocol messages и transport security.
- `src/observability/` и `src/ratelimit/` являются общей инфраструктурой, а не принадлежат одному transport.
- `src/roxy_application.gleam` только собирает config, dependencies и supervision tree.

### Findings

- Направление зависимостей в целом корректно: transport зависит от application/infrastructure; application access model не знает о Wisp, Mist, HTTP status или WebSocket representation.
- HTTP и WebSocket имеют отдельные routers, error representations и lifecycle.
- `application/services/session.gleam` зависит от pog. Для текущего небольшого foundation это прагматичный application service, а не подтверждённая архитектурная проблема; выделять repository abstraction до появления реальных use cases не требуется.
- God-files и циклический архитектурный coupling не обнаружены.
- `application/dependencies.gleam` содержит небольшие convenience wrappers вокруг pool/pog. Они не создают второй owner и пока не оправдывают рефакторинг.

### Changes

Изменения не вносились.

### Remaining considerations

При добавлении бизнес-фичей domain types должны оставаться независимыми от Wisp/Mist/pog. Use cases следует добавлять в `application/`, а HTTP/WS handlers должны только преобразовывать transport input/output и вызывать use case.

---

## 2. Single source of truth и cohesion

**Status: Needs attention**

### Current approach

- HTTP body limits принадлежат `transport/http/protocol/limits.gleam`.
- WebSocket message/connection/rate policies принадлежат `transport/websocket/protocol/limits.gleam` и `ratelimit/policy.gleam`.
- API error codes/messages принадлежат `shared/api/error.gleam`.
- Config defaults разделены между application и database owners.
- Route access/method/body contracts объявлены рядом с router.

### Findings

- Существенного дублирования policy/error constants не найдено.
- `result_map` вручную дублирует официальный `supervision.map_data` в `observability/metrics.gleam` и `ratelimit/limiter.gleam`. Текущий код корректен, finding низкого приоритета.
- Migration history insert вручную формирует SQL, хотя pog уже предоставляет parameters. Источник version локальный и проверяемый, поэтому внешняя SQL injection не подтверждена, но официальный parameter API проще и надёжнее.
- Имена `roxy_postgres`, `roxy_metrics`, `roxy_rate_limiter`, cookie `roxy_session` и startup message разбросаны по владельцам. Это не runtime defect, но копирование skeleton требует ручного поиска project identity.

### Changes

Изменения не вносились.

### Remaining considerations

- Заменить локальные `result_map` на `supervision.map_data` при ближайшем изменении соответствующих модулей.
- Параметризовать insert в `schema_migrations`.
- Если backend действительно будет копироваться как отдельный template, собрать application identity/cookie/process names в одном небольшом config/identity owner. Не создавать глобальный constants-файл для несвязанных значений.

---

## 3. Secure-by-default

**Status: Needs attention**

### Current approach

HTTP route содержит обязательные поля `methods`, `body`, `access` и `handler`. Public access задаётся явно через `access.Public`; protected policies представлены `Authenticated` и `Permission`. Unknown route получает `404`, неизвестный method для существующего resource — `405` с `Allow`.

WebSocket route также содержит explicit methods/access, а validation origin и upgrade headers выполняется до authorization и до `mist.websocket`.

### Findings

Положительные свойства:

- Невозможно объявить HTTP/WS route без access policy на уровне типа `Route`.
- Public routes видимы явно.
- Unknown HTTP method/resource не обходит routing и authorization.
- Origin allowlist exact-match и CORS explicit; wildcard policy не используется.
- CSRF policy применяется до routing/handler для unsafe HTTP methods.
- Session token не логируется; cookies, authorization headers и body не входят в logging fields.
- Session token генерируется CSPRNG, в PostgreSQL хранится SHA-256 hash.
- Cookie использует `HttpOnly`, `SameSite=Lax`, а production — `Secure`.

Подтверждённые проблемы:

- `/ws` — публичный echo endpoint. Это placeholder/test behavior, который в production становится публичной функциональностью без business ownership.
- Public routes всегда вызывают `session.principal` до `access.authorize(Public, ...)`. Клиент с произвольным cookie может заставлять `/health`, `/ready` и `/ws` обращаться к PostgreSQL. Для `/health` это нарушает чистую liveness semantics и создаёт публичный DB workload.
- WebSocket key проверяется только на непустое значение. RFC 6455 требует base64 от 16 bytes.
- `Sec-WebSocket-Extensions: permessage-deflate` может быть принят Mist. При этом application limit проверяется только после decompression.

### Changes

Изменения не вносились.

### Remaining considerations

До production использования WebSocket:

1. Не публиковать echo route в production; оставить его test-only/development-only либо заменить реальным route с явным access contract.
2. Для `Public` не выполнять session lookup. Если понадобится optional identity, выразить её отдельной policy, а не неявно загружать session для каждого public route.
3. Строго декодировать `Sec-WebSocket-Key` и требовать 16 bytes.
4. Не согласовывать compression, пока transport не умеет bounded decompression.

Resource-level authorization должна добавляться внутри use case/handler для конкретного resource; route-level permission не заменяет проверку ownership entity.

---

## 4. HTTP transport flow

**Status: Needs attention**

### Current approach

Фактическая композиция:

1. Mist принимает request.
2. `transport/dispatcher.gleam` создаёт context.
3. Проверяется production transport policy.
4. Применяется HTTP rate limiter.
5. WebSocket router получает возможность match до Wisp adapter.
6. Остальные requests проходят через `wisp_mist.handler`.
7. HTTP router создаёт новый context, выставляет Wisp body/file limits и применяет logging → CORS → cache policy → error boundary → CSRF → HEAD handling → route/method/access/body contract → handler.
8. Security headers и request ID добавляются к response.

### Findings

- Wisp body/file limits задаются до parsing и handler.
- Error mapper не раскрывает stack trace/internal exception клиенту.
- Middleware order в целом обеспечивает требуемые гарантии, хотя форма отличается от примерной схемы в ТЗ.
- Dispatcher и HTTP router создают разные request IDs. Error body/log используют внутренний ID, затем внешний dispatcher перезаписывает `x-request-id` другим ID.
- Insecure transport и rate-limit responses формируются до Wisp logging/metrics/error middleware, поэтому security rejects не получают единый completion event.
- `actor.call` limiter может crash/timeout до Wisp safety boundary. В таком случае Mist формирует собственный plain `500`, без application JSON, CORS/security headers и request ID.
- При ошибке `mist.get_connection_info`, limiter полностью пропускается (`None -> dispatch`), то есть fail-open.

### Changes

Изменения не вносились.

### Remaining considerations

- Создавать один `TransportContext` на самом внешнем application boundary и передавать его в HTTP/WS ветки и error mappings.
- Обернуть весь dispatch после создания context единым safety boundary.
- Limiter API должен возвращать typed `Unavailable`, а не аварийно завершать caller при timeout/dead actor; наружу отображать контролируемый `503`.
- Учитывать transport-policy/rate-limit rejects в общем HTTP completion logging/metrics без двойных событий.

---

## 5. WebSocket lifecycle

**Status: Needs attention**

### Current approach

Lifecycle разделён на route match → method/origin/handshake validation → session/access → connection slot → `mist.websocket` upgrade → `on_init` → message handler → `on_close` cleanup.

Mist запускает WebSocket processes под собственным factory supervisor как temporary children, поэтому падение connection process не перезапускает socket и не роняет listener.

### Findings

Положительные свойства:

- Security validation выполняется до upgrade.
- Connection имеет отдельный `connection_id` и сохраняет handshake `request_id`.
- Message handler имеет crash boundary.
- Rate-limit и oversized message закрывают только connection.
- `on_close` освобождает limiter capacity и пишет metrics/log.

Подтверждённые проблемы:

- Connection slot увеличивается до `mist.websocket`. Если Mist отвергнет malformed upgrade или не запустит child, `on_close` не будет вызван и slot останется занят.
- Scalar counter с `CloseWebsocket` не идемпотентен и не связывает release с конкретной reservation. Повторный release способен освободить capacity другого connection.
- `actor.call` timeout может завершить request process, а queued `OpenWebsocket` позже всё равно увеличить counter.
- `x-request-id`, установленный после `mist.websocket`, не гарантированно попадает в уже отправленный клиенту `101`.

### Changes

Изменения не вносились.

### Remaining considerations

Использовать lease-based reservation:

- `open_websocket(lease_id)`;
- idempotent `release(lease_id)`;
- release при exception, timeout и любом результате с body не `mist.Websocket`;
- перенос lease в connection state только после успешной инициализации.

Если Mist не позволяет добавить custom headers в фактически отправляемый `101`, correlation ID следует передавать первым server protocol message после connection. Не использовать internal Mist modules ради этого.

---

## 6. Ошибки и external representations

**Status: OK**

### Current approach

- Общие access errors принадлежат `application/access.gleam`.
- Session verification errors принадлежат application session service.
- HTTP transport errors принадлежат `transport/http/protocol/http_errors.gleam`.
- WebSocket handshake errors принадлежат `transport/websocket/handshake/validation.gleam`.
- HTTP и WS имеют независимые mappings во внешний protocol.
- Общий wire contract кодов/messages находится в `shared/api/error.gleam`.

### Findings

- Общего error enum-свалки нет.
- Application errors не зависят от HTTP status или WebSocket close representation.
- Internal DB/exception details не возвращаются клиенту.
- Ручная сборка JSON в Mist-level errors безопасна для текущих constant messages и generated URL-safe request ID, но `gleam_json` даст более устойчивый contract при появлении динамических данных.

### Changes

Изменения не вносились.

### Remaining considerations

Добавить отдельное transport mapping для `LimiterUnavailable`. Не добавлять его в application/domain error types.

---

## 7. Configuration

**Status: Needs attention**

### Current approach

- `APP_ENV` обязателен и имеет закрытый тип `Development | Production`.
- Config загружается один раз при startup и передаётся через `Dependencies`.
- Production требует `PORT`, `SECRET_KEY_BASE`, origins, public URL, trusted peers и DB budgets.
- Production `PUBLIC_BASE_URL` обязан использовать HTTPS.
- Development defaults ограничены development branch.
- Secret production fallback отсутствует; длина secret проверяется.

### Findings

- Typed/fail-fast подход в целом корректен.
- `TRUSTED_PROXY_IPS` и `TRUSTED_INTERNAL_IPS` валидируются только как непустые строки. Значения вроде `proxy` или `10.0.0.999` проходят startup, но никогда не совпадут с canonical Mist peer IP.
- `.env` loader безусловно вызывает `envoy.set`, поэтому локальный `.env` может перезаписать уже заданные process environment variables. Обычная и более безопасная dotenv semantics — environment wins.
- `PUBLIC_BASE_URL` parser принимает URI с дополнительными components шире, чем CORS parser; это не доказанный bypass transport policy, но canonical absolute origin contract стоит унифицировать.

### Changes

Изменения не вносились.

### Remaining considerations

- Парсить trusted IPv4/IPv6 при startup и хранить canonical representation. CIDR не добавлять без реальной необходимости.
- `.env` устанавливать только для отсутствующих process variables либо убрать runtime dotenv loader и оставить Compose/env injection.

---

## 8. Transport security и reverse proxy

**Status: Needs attention**

### Current approach

- Backend сам не выпускает и не хранит TLS certificates.
- Development допускает HTTP/WS localhost.
- Production требует HTTPS public base URL.
- Внутренний HTTP/WS допускается только от explicit trusted internal peers или trusted proxy с `X-Forwarded-Proto: https`.
- Forwarded proto не принимается от произвольного peer.
- HSTS добавляется для production HTTPS configuration.

### Findings

- Foundation не зависит именно от HAProxy; подойдёт любой trusted TLS terminator/reverse proxy.
- Application transport policy остаётся active без HAProxy и deny-by-default в production.
- HTTP limiter использует direct peer IP. За reverse proxy все пользователи делят один bucket в 5 requests/second, поэтому один клиент может блокировать остальных.
- Forwarded client IP пока не используется. Простое доверие `X-Forwarded-For` недопустимо; значение должно приниматься только от trusted direct peer и ingress должен перезаписывать header.
- Production Compose публикует backend только на `127.0.0.1`, что уменьшает exposure при локальном deployment.

### Changes

Изменения не вносились.

### Remaining considerations

Ввести каноническую `ClientIdentity`:

- direct peer для прямого trusted internal traffic;
- строго распарсенный client IP из `Forwarded`/`X-Forwarded-For` только когда direct peer входит в trusted proxies;
- malformed/missing identity от trusted proxy — fail closed или отдельный сильно ограниченный fallback bucket;
- direct client не может подменить forwarded headers.

Также зафиксировать deployment contract: ingress обязан удалить клиентские forwarded headers и установить собственные.

---

## 9. Observability

**Status: Needs attention**

### Current approach

- Общий logger пишет key-value structured events.
- HTTP имеет request completion event с method/path/status/duration/request_id.
- WebSocket имеет handshake/connected/closed/error events с request_id и connection_id.
- In-memory metrics actor собирает HTTP/WS/session/CSRF/DB counters.
- `/health` — liveness, `/ready` — PostgreSQL connectivity probe.

### Findings

- Cookies, tokens, authorization headers и body не логируются.
- Logger экранирует value только если оно содержит обычный пробел. Значение с newline без пробела может создать дополнительную log line. В logger передаются request path и будущий user_id, поэтому это реальный log-integrity risk.
- HTTP и WS latency измеряются wall clock (`timestamp.system_time`), который может прыгать назад. В проекте уже есть monotonic FFI clock для limiter.
- `metrics.disabled()` создаёт новый Erlang atom через `process.new_name` на каждый вызов. Atoms не освобождаются. Кроме того, disabled subject не имеет consumer, и `record` может оставлять сообщения в mailbox вызывающего процесса.
- Metrics snapshot не экспортируется наружу production-коду; `SupervisorRestarted` нигде не записывается.
- Public health requests без cookie создают `session_missing` event; с cookie могут выполнять DB lookup до самого handler.

### Changes

Изменения не вносились.

### Remaining considerations

- Всегда безопасно сериализовать logger fields: JSON logging либо безусловный `string.inspect`/полное escaping control characters.
- Использовать monotonic clock для durations, wall clock оставить для timestamp.
- Представить disabled metrics отдельным variant с no-op `record`, без `Name` и `Subject`.
- Либо экспортировать полезные metrics через защищённый/internal endpoint, либо временно убрать неиспользуемые counters. Не добавлять тяжёлую telemetry infrastructure без consumer.
- Public liveness/readiness не должны разрешать optional session lookup.

---

## 10. PostgreSQL foundation

**Status: Needs attention**

### Current approach

- Один named pog pool строится в `db/pool.gleam` и принадлежит root supervisor.
- Pool size и PostgreSQL server/client time budgets typed и валидируются.
- Readiness выполняет реальный `select 1` с crash protection.
- Migration files сортируются, applied versions хранятся в `schema_migrations`.
- Каждая migration и history insert выполняются в одной transaction.
- Migration failure возвращается наружу и завершает CLI abnormal exit.

### Findings

- Pool ownership и lifecycle корректны; дублирующего pool owner нет.
- Migration CLI запускает asynchronous pool и сразу выполняет SQL, хотя `pool.wait_until_ready` уже существует и используется integration tests.
- Production image копирует только Erlang shipment; `backend/migrations/` отсутствует. Команда `backend_migrations` в production artifact не имеет SQL files.
- Production deployment не содержит documented one-shot migration job.
- `/ready` проверяет только connectivity, а не наличие ожидаемой schema version. При external migration orchestration это допустимо только если orchestrator гарантирует порядок; текущий Compose такого migration step не содержит.
- Документация требует уникальный numeric prefix, но код считает version полным filename stem. `0001_first.sql` и `0001_second.sql` обе будут применены.
- Integration migration test создаёт пустую directory, не исполняет реальные migration files и превращает build/readiness errors в успешное завершение теста.
- Существующие `sessions` migrations — не фиктивные таблицы для проверки механизма: session/auth является реальной foundation responsibility. Однако expired/revoked rows никогда не удаляются, поэтому таблица растёт без ограничения.
- `DATABASE_URL` определяет PostgreSQL SSL mode. Если DB внешняя и сеть недоверенная, production config должен требовать verified TLS; для private container network TLS не обязательно.

### Changes

Изменения не вносились.

### Remaining considerations

До production readiness:

1. В migration CLI вызвать bounded `pool.wait_until_ready` и всегда остановить supervisor.
2. Добавить migrations в production image либо отдельный migration image/job.
3. Документировать и выполнять one-shot migration до rollout backend.
4. Проверять duplicate numeric prefixes при загрузке files.
5. Исполнять реальные migrations в opt-in integration test; при включённом integration mode connection failure должен проваливать test.
6. Добавить простую maintenance cleanup expired/revoked sessions до появления значимого объёма данных.
7. Для external PostgreSQL явно задать `sslmode=verify-full`/verified SSL согласно deployment topology.

---

## 11. Resource protection

**Status: Needs attention**

### Current approach

- HTTP body limit: 1 MiB.
- Multipart aggregate file limit: 32 MiB.
- HTTP fixed-window limiter: 5 requests/second per key.
- WebSocket message limit: 64 KiB.
- WebSocket message limiter: 10 messages/second per connection.
- WebSocket active connection limit: 100.
- Limiter buckets очищаются при каждом `Check`; single-instance state соответствует текущему requirement.

### Findings

- HTTP Wisp limits применяются во время чтения body до parsing/handler и используют исправленный Wisp 2.2.2.
- Expired limiter buckets не растут бесконечно, пока поступают новые checks. При полном отсутствии traffic state остаётся bounded числом последних identities; periodic cleanup не обязателен для текущей модели.
- WebSocket message size проверяется слишком поздно: Mist уже прочитал payload, Gramps декодировал frames, собрал continuation frames и мог распаковать `permessage-deflate`. Large frame/fragmented message/compression bomb расходуют memory/CPU до application check.
- Mist 6.0.3 не предоставляет публичной настройки early frame/message/decompressed-size limit.
- Отдельного backend cap для incomplete TCP connections/HTTP headers/pre-upgrade handshake не обнаружено. Ingress limits помогают, но foundation не должен считать HAProxy обязательной частью application correctness.

### Changes

Изменения не вносились.

### Remaining considerations

Блокирующее для публичного WebSocket:

- до появления bounded transport API не публиковать generic echo WS в production;
- запретить negotiation `permessage-deflate`;
- выбрать transport/library version с limits на declared frame payload, aggregate fragmented message, socket buffer и decompressed output либо добавить это upstream в Mist/Gramps через публичный API.

TCP/slow-header connection cap следует либо обеспечить поддерживаемой настройкой Mist/glisten, либо явно определить bounded ingress как deployment requirement. Не использовать internal library modules в skeleton.

---

## 12. OTP и lifecycle

**Status: OK**

### Current approach

Root `RestForOne` supervisor запускает children в порядке:

1. pog pool;
2. rate limiter;
3. metrics;
4. Mist HTTP server.

Root owner остаётся жив через `process.sleep_forever`. Mist отдельно supervises WebSocket connection processes.

### Findings

- Child order соответствует dependencies: падение ранней инфраструктуры перезапускает downstream children.
- Один request/connection не роняет весь backend.
- WebSocket child имеет temporary semantics внутри Mist factory supervisor.
- Long-lived foundation processes находятся под supervision.
- Restart tolerance задан явно: 3 restarts/10 seconds.
- Production Compose не задаёт container restart policy. После исчерпания supervisor tolerance container останется stopped, если внешний orchestrator отсутствует.
- OTP documentation не показывает metrics child, а shutdown test подтверждает завершение children, но не фактический dependency order, несмотря на название.

### Changes

Изменения не вносились.

### Remaining considerations

- Для предоставленного standalone Compose добавить `restart: unless-stopped`; если restart гарантирует orchestrator, явно документировать это.
- Обновить supervision diagram/documentation и переименовать либо усилить shutdown-order test.

---

## 13. Актуальность Gleam ecosystem

**Status: OK**

### Current approach

Проверены direct и transitive pins из `manifest.toml`, официальные Hex package metadata, HexDocs и официальные source/release pages.

### Findings

На дату аудита актуальны:

| Component | Pinned | Latest stable checked |
|---|---:|---:|
| Gleam | 1.18.1 | 1.18.1 |
| gleam_stdlib | 1.0.5 | 1.0.5 |
| gleam_erlang | 1.3.0 | 1.3.0 |
| gleam_otp | 1.3.0 | 1.3.0 |
| gleam_http | 4.4.0 | 4.4.0 |
| gleam_json | 3.1.0 | 3.1.0 |
| gleam_time | 1.10.0 | 1.10.0 |
| Wisp | 2.2.2 | 2.2.2 |
| Mist | 6.0.3 | 6.0.3 |
| pog | 4.1.0 | 4.1.0 |
| logging | 1.5.0 | 1.5.0 |
| envoy | 1.2.0 | 1.2.0 |
| simplifile | 2.7.0 | 2.7.0 |
| gleam_crypto | 1.6.0 | 1.6.0 |
| exception | 2.1.1 | 2.1.1 |
| gleeunit | 1.11.0 | 1.11.0 |
| gleam_httpc | 5.0.0 | 5.0.0 |

- Все runtime transitive dependencies в lockfile также совпадали с latest stable Hex metadata.
- Wisp 2.2.2 содержит исправление multipart resource-exhaustion vulnerability; снижать нижнюю границу нельзя.
- Production code не использует deprecated или `*/internal` modules.
- `wisp_mist.handler` → `mist.new` → `mist.supervised` соответствует официальному adapter/supervision flow.
- Mist WebSocket API и pog named pool/transactions/query parameters используются корректно.
- `exception.rescue` применяется как crash boundary, а не обычный control flow.
- Тесты используют `wisp.create_canned_connection`, который помечен `@internal`. Публичная замена — `wisp/simulate`.
- Самописный monotonic Erlang FFI оправдан: публичного equivalent в текущем Gleam time API нет.

### Changes

Изменения не вносились.

### Remaining considerations

Перевести HTTP unit tests с `wisp.create_canned_connection` на публичный `wisp/simulate`, чтобы будущий minor/major upgrade Wisp не ломал test infrastructure.

### Official sources

- Gleam releases: https://github.com/gleam-lang/gleam/releases/tag/v1.18.1
- Wisp 2.2.2: https://hexdocs.pm/wisp/2.2.2/
- Wisp/Mist adapter: https://hexdocs.pm/wisp/2.2.2/wisp/wisp_mist.html
- Wisp simulate: https://hexdocs.pm/wisp/2.2.2/wisp/simulate.html
- Wisp multipart advisory: https://github.com/gleam-wisp/wisp/security/advisories/GHSA-8645-p2v4-73r2
- Mist 6.0.3: https://hexdocs.pm/mist/6.0.3/mist.html
- pog 4.1.0: https://hexdocs.pm/pog/4.1.0/pog.html
- gleam_otp supervision: https://hexdocs.pm/gleam_otp/1.3.0/gleam/otp/supervision.html
- gleam_erlang process: https://hexdocs.pm/gleam_erlang/1.3.0/gleam/erlang/process.html
- gleam_time: https://hexdocs.pm/gleam_time/1.10.0/gleam/time/timestamp.html
- gleam_crypto: https://hexdocs.pm/gleam_crypto/1.6.0/gleam/crypto.html
- gleam_json: https://hexdocs.pm/gleam_json/3.1.0/gleam/json.html
- logging: https://hexdocs.pm/logging/1.5.0/logging.html
- exception: https://hexdocs.pm/exception/2.1.1/exception.html
- Erlang monotonic time: https://www.erlang.org/doc/apps/erts/erlang.html#monotonic_time/1

---

## 14. Reusable skeleton

**Status: Needs attention**

### Current approach

Foundation уже содержит config, HTTP/WS boundaries, access/session primitives, common errors, PostgreSQL pool/migrations, rate limiting, observability и OTP lifecycle. Hosting provider-specific SDK/coupling, generated TLS certificates, Redis/distributed coordination и fake domain entities отсутствуют.

### Findings

- Обязательной зависимости от HAProxy нет; документация допускает любой reverse proxy/TLS terminator.
- MinIO присутствует в repository Compose, но backend dependency/import на него не найден. Это не backend foundation dependency.
- `sessions` является foundation authentication storage, а не фиктивной business entity.
- Публичный echo `/ws` является случайной placeholder functionality и не должен попадать в copied production skeleton.
- Project identity `roxy` присутствует в internal names/defaults и требует адаптации при копировании.
- Production Compose documentation противоречива: текст утверждает, что PostgreSQL находится за `local-infra`, но `docker-compose.prod.yml` запускает его без profile и backend зависит от него. Backend подключён только к `internal: true` database network, поэтому этот Compose не реализует документированный external DB scenario.

### Changes

Изменения не вносились.

### Remaining considerations

- Явно разделить local production-like stack и настоящий deployment example, либо исправить документацию согласно фактической цели Compose.
- Для deployment с external DB убрать обязательный `depends_on: postgres` и предоставить network egress.
- Убрать production echo endpoint.
- Сконцентрировать только project identity values, не превращая config в framework.

---

## 15. Рекомендуемый порядок исправлений

### P0 — blocking foundation issues

1. Закрыть production `/ws` до появления early bounded WebSocket transport limits; отключить compression negotiation.
2. Исправить rate-limit identity за trusted proxy и убрать fail-open при peer metadata error.
3. Сделать limiter failures typed и поместить весь dispatch под единый safe error boundary.
4. Заменить WebSocket scalar slot на idempotent lease и гарантировать release на failed upgrade/timeout.
5. Добавить production migration artifact/job и bounded wait for pool readiness.

### P1 — до добавления первых protected routes

1. Один `TransportContext` на request/handshake.
2. Public access без session lookup; optional auth — отдельная explicit policy.
3. Строгая validation `Sec-WebSocket-Key`.
4. Валидировать trusted IPs при startup.
5. Исправить logger control-character escaping.
6. Исправить `metrics.disabled()` без atom/subject allocation.
7. Проверять duplicate migration prefixes и real migration integration path.

### P2 — качество и эксплуатация

1. Monotonic latency measurements.
2. Решить, экспортируются metrics или abstraction пока удаляется.
3. Session cleanup maintenance.
4. Container restart policy/documented orchestrator contract.
5. `wisp/simulate` в tests.
6. Обновить OTP/Compose/migration documentation.

---

## Validation

До подготовки отчёта было подтверждено:

- `gleam check` — успешно в исходном состоянии проекта.
- `gleam test` — 95 tests passed, no failures в исходном состоянии проекта.
- `docker compose -f docker-compose.yml -f docker-compose.prod.yml config` — успешно; одновременно подтвердил безусловный local PostgreSQL и internal-only backend network.
- Версии direct/transitive packages сверены с Hex metadata и официальной документацией.

Ограничения проверки:

- Реальные PostgreSQL integration guarantees не подтверждены текущим обычным `gleam test`: integration tests условно пропускаются, а migration integration test допускает false green при connection failure.
- Production image runtime inspection не выполнен; Docker daemon был недоступен. Отсутствие migrations подтверждено статически по `backend/Dockerfile.prod`.
- Повторный локальный export shipment не выполнен из-за отсутствующего `rebar3.cmd` в host environment.
- После запроса пользователя код не изменялся; создан только этот audit report.

---

# Verdict

## Ready for business features: NO

### Blocking issues

1. Публичный WebSocket flow не имеет раннего bounded message/decompression limit; текущая application проверка срабатывает после дорогой обработки.
2. HTTP rate limiting некорректен для production reverse proxy topology и fail-open при недоступном peer metadata.
3. Limiter actor failure/timeout может обойти application safety/error pipeline.
4. WebSocket connection capacity может утекать при failed upgrade/start.
5. Production artifact/deployment path не обеспечивает выполнение доступных migrations до readiness backend.

После устранения этих пяти пунктов foundation можно считать готовым к добавлению business entities/use cases без предварительной перестройки архитектуры. Остальные findings являются локальными hardening/operability задачами и не требуют смены выбранной структуры слоёв.