# Backend foundation: feature-gap audit

Дата: 2026-09-10. Scope: универсальные возможности до бизнес-фич; без аудита архитектуры, ошибок реализации и микрооптимизаций.

**Вывод:** foundation уже достаточно полный для начала бизнес-фич в development: session lifecycle, CSRF и передача verified identity в handlers закрыты. До публичного production остаются ingress/WS resource budgets и deployment-контракт. Переписывать foundation не требуется.

`Missing` означает отсутствующий механизм или его подключение, а не автоматически блокер любой разработки. Приоритеты ниже разделяют начало разработки, authenticated writes и выход в production.

## Основания и документация

Проверены `backend/src`, тесты, manifest, Docker/Compose и документация проекта. Версии взяты из `backend/manifest.toml`, а не из открытых диапазонов `gleam.toml`: **Wisp 2.2.2, Mist 6.0.3, pog 4.1.0 / pgo 0.20.0, gleam_otp 1.3.0, glisten 9.0.1, gramps 6.0.1**; Gleam **1.18.1** подтверждён Dockerfile и локальным `gleam --version`.

Официальные источники для закреплённых версий:

- [Gleam 1.18.1 release](https://github.com/gleam-lang/gleam/releases/tag/v1.18.1).
- [Wisp 2.2.2: API-документация в исходнике](https://github.com/gleam-wisp/wisp/blob/v2.2.2/src/wisp.gleam), [Mist adapter и cleanup](https://github.com/gleam-wisp/wisp/blob/v2.2.2/src/wisp/wisp_mist.gleam).
- [Mist 6.0.3: WebSocket lifecycle](https://github.com/rawhat/mist/blob/v6.0.3/src/mist/internal/websocket.gleam), [HTTP API](https://github.com/rawhat/mist/blob/v6.0.3/src/mist.gleam).
- [glisten 9.0.1: socket defaults](https://github.com/rawhat/glisten/blob/v9.0.1/src/glisten/socket/options.gleam), [gramps 6.0.1: framing](https://github.com/rawhat/gramps/blob/v6.0.1/src/gramps/websocket.gleam), [compression](https://github.com/rawhat/gramps/blob/v6.0.1/src/gramps/websocket/compression.gleam).
- [pog 4.1.0](https://github.com/lpil/pog/blob/v4.1.0/src/pog.gleam), [pgo 0.20.0: pool deadlines](https://github.com/erleans/pgo/blob/v0.20.0/src/pgo_pool.erl), [OTP 1.3.0: supervision](https://github.com/gleam-lang/otp/blob/v1.3.0/src/gleam/otp/supervision.gleam).
- [crypto 1.6.0](https://github.com/gleam-lang/crypto/blob/v1.6.0/src/gleam/crypto.gleam), [envoy 1.2.0](https://github.com/lpil/envoy/blob/v1.2.0/src/envoy.gleam), [exception 2.1.1](https://github.com/lpil/exception/blob/v2.1.1/src/exception.gleam), [gleeunit 1.11.0](https://github.com/lpil/gleeunit/blob/v1.11.0/src/gleeunit.gleam).

HexDocs оказался недоступен; использованы официальные tagged sources с API-документацией и локальные исходники пакетов в `backend/build/packages`. Дополнительно сверены применимые контракты `gleam_http 4.4.0`, `logging 1.5.0`, `simplifile 2.7.0`; обновление зависимостей не оценивалось.

## Уже закрыто

| Область | Статус | Основание |
|---|---|---|
| HTTP routing, middleware, методы и ответы | **Already covered** | `transport/http/router.gleam` содержит route/method dispatch, 404/405 с `Allow`, HEAD через Wisp; protocol-модули задают ответы и ошибки. JSON/multipart parsing подготовлен; отсутствие всех CRUD-методов до появления маршрутов не является пробелом. |
| Authentication/access primitives | **Already covered** | `application/access.gleam`, `application/services/session.gleam`, `transport/session.gleam`: server-side session verification, principal с generic permissions, Public/Authenticated/Permission policy и разделение 401/403. Полный session lifecycle и передача verified identity в HTTP/WS context также подключены. |
| CORS и credentialed requests | **Already covered** | `transport/http/middleware/cors.gleam`, `protocol/cors.gleam`, `config/origins.gleam`: allowlist, preflight, credentials и `Vary`; текущие методы соответствуют существующим маршрутам. CORS не заменяет защиту от выполнения нежелательного запроса. |
| WS handshake и Origin validation | **Already covered** | `transport/websocket/handshake/validation.gleam` и `router.gleam` проверяют Origin, метод и upgrade/version; Mist завершает handshake. Публичность echo `/ws` сама по себе не является отсутствием access foundation. |
| WS базовый lifecycle | **Already covered** | `transport/websocket/handlers/socket.gleam`: connect/close/error, release capacity и обработка send failure; Mist обрабатывает Ping/Close. Отдельно ниже отмечено отсутствие reclaim молчащих соединений. |
| Body/message limits и существующие timeouts | **Already covered** | HTTP: 1 MiB body и суммарно 32 MiB multipart files; WS: 64 KiB доставленного сообщения (`transport/*/protocol/limits.gleam`). Mist даёт 15 s на отдельное чтение и 10 s HTTP keep-alive idle, glisten — active-once и 30 s send timeout; это не общий deadline запроса и не pre-decode лимит WS. |
| Rate limiting | **Already covered** | `ratelimit/limiter.gleam`, `policy.gleam`, `transport/dispatcher.gleam`: HTTP 5/s на peer, WS 10 сообщений/s на соединение, до 100 WS, ограниченные limiter calls. Handshake проходит через HTTP limiter; отдельный механизм только ради handshake не обязателен. |
| Security headers | **Already covered** | `transport/http/middleware/security_headers.gleam`: `nosniff`, referrer policy, условный HSTS. CSP/frame policy для frontend HTML не следует считать отсутствующей универсальной возможностью JSON backend. |
| HTTPS/WSS policy и доверие proxy | **Already covered** | `config/transport.gleam`, `transport/transport_security.gleam` задают production HTTPS и доверенные peers для forwarded scheme. Реализация публичного edge ещё отложена — см. deployment gap ниже. |
| Centralized config/secrets/fail-fast | **Already covered** | `config/app.gleam`, `config/transport.gleam`, `db/config.gleam`: типизированная конфигурация, обязательные production env, проверки порта, secret length, pool size/timeouts и URL при построении pool. Runtime env без секретов в образе достаточно для foundation; отдельный secret manager не обязателен. |
| Error handling | **Already covered** | `transport/http/middleware/error_handler.gleam`, protocol errors и WS error handlers дают общий прикладной контракт и безопасный ответ при исключениях. Унификация всех ошибок сетевого сервера/edge с JSON envelope не обязательна. |
| Structured logs и correlation IDs | **Already covered** | `observability/logger.gleam`, `transport_context.gleam`, WS `connection/context.gleam`: структурированные key/value события, request ID и отдельный connection ID с корреляцией. JSON-формат и distributed tracing не являются обязательным недостающим foundation. |
| Health/readiness | **Already covered** | `/health` и `/ready` разделены; readiness делает `select 1` и возвращает 503 при недоступной DB (`application/dependencies.gleam`). Compose использует readiness healthcheck. |
| PostgreSQL pool, transactions, migrations | **Already covered** | `db/pool.gleam` строит supervised pog pool; `db/migrations.gleam` ведёт историю и применяет миграцию с её записью в одной транзакции. Transaction API уже доступен в pog — отдельная архитектурная обёртка до бизнес-фич не нужна. |
| OTP supervision и базовое завершение | **Already covered** | `roxy_application.gleam`: `RestForOne`, порядок DB → limiter → metrics → HTTP, restart budget; Compose задаёт `init` и stop grace. Это не доказательство graceful draining реального трафика. |
| Cleanup временного/in-memory state | **Already covered** | Limiter удаляет просроченные buckets лениво и освобождает WS capacity при штатном close; Wisp Mist adapter удаляет request-scoped multipart temp files через `exception.defer`. Отдельный sweeper не нужен только ради наличия sweeper. |
| Test/integration infrastructure | **Already covered** | `backend/test` содержит unit, HTTP/WS network, pool/migrations и OTP тесты; `gleeunit.main()` обнаруживает тестовые модули. Docker-команда запуска с PostgreSQL документирована в README; отсутствие CI не равно отсутствию тестовой инфраструктуры. |
| Container baseline | **Already covered** | Корневой `Dockerfile`: multi-stage shipment, non-root runtime без compiler; production Compose: internal networks, healthcheck, stop grace. Финальная публичная схема развёртывания пока не завершена. |

Пути в этой таблице без префикса относятся к `backend/src/`.

## Реально отсутствующие возможности

| Пункт | Статус | Почему и когда закрыть |
|---|---|---|
| Полный session lifecycle и единая cookie policy | **Already covered** | `application/services/session.gleam` теперь создаёт 256-bit opaque token, хранит только SHA-256 hash, проверяет server-side expiry и revoked state, а `transport/session.gleam` даёт issue/revoke/principal API. Cookie policy централизована: `HttpOnly`, `SameSite=Lax`, `Path=/`, production `Secure`, TTL из `SESSION_TTL_SECONDS` (60–2,592,000 секунд) и fail-fast validation. |
| HTTP CSRF gate | **Already covered** | `transport/http/middleware/csrf.gleam` пропускает safe methods и CORS preflight, для unsafe requests проверяет `Origin` с fallback на `Referer` по allowlist frontend origins и public backend origin. Чужой/некорректный origin получает единый 403 `csrf_forbidden`, а при отсутствии browser origin headers cookies удаляются до auth/routing, сохраняя безопасные non-browser requests. |
| Передача verified identity в HTTP handlers | **Already covered** | `transport/http/router.gleam` передаёт результат `access.authorize` в immutable `TransportContext`, поэтому handlers получают один раз проверенный principal через `transport_context.principal` без повторного чтения cookie. Server-side session хранит snapshot generic permissions и восстанавливает `Principal` через `access.principal_with_permissions`; конкретные роли и правила обновления permissions остаются бизнес-политикой. |
| WS budgets до декодирования и распаковки | **Missing** | Ограничение 64 KiB срабатывает после передачи сообщения приложению; в закреплённых Mist/gramps не найден бюджет накопления incomplete frames/декомпрессии до callback. До untrusted WS нужны ограничения на соответствующем слое и явная compression policy; обычный HTTP reverse proxy после Upgrade не следует автоматически считать защитой декодера. |
| Reclaim idle/stale WS | **Missing** | WS state/selector не содержит idle expiry или heartbeat с deadline, а автоматический Pong не обнаруживает молчащего peer (`websocket/handlers/socket.gleam`, `connection/context.gleam`). До публичного использования добавить одну осмысленную liveness policy, чтобы ограниченные connection slots не удерживались бесконечно. |
| Управляемый drain при остановке | **Missing** | Нет прикладного перехода readiness → not-ready, прекращения admission и ограниченного ожидания активных HTTP/WS перед остановкой зависимостей. Это эксплуатационный gap перед rolling deployments, не блокер написания фич; имеющиеся OTP-тесты с fake children не проверяют такой контракт. |

## Можно отложить без переделки foundation

| Пункт | Статус | Причина |
|---|---|---|

| Обязательный изолированный integration-test job | **Consider later** | Базовый harness есть, но DB migration test допускает пропуск при недоступной DB и использует dev DB. До CI/release gate добавить отдельную test DB и режим, где отсутствие DB означает failure, плюс lifecycle/security regression tests для новых механизмов. |

## Границы проверки

Это статический capability audit, не security certification. Tests/build/container startup не запускались: для выводов об отсутствии механизмов использованы исходники и документация, а не предполагаемый результат тестов; существующие тесты не объявляются прошедшими. Код и конфигурация не изменены.
