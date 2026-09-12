# Backend foundation checklist

Этот checklist составлен по результатам `backend-foundation-audit.md`.

## Как читать результат

- **P0 — blocking**: нужно закрыть до того, как foundation можно считать готовым для production-facing business features.
- **P1 — required hardening**: желательно закрыть до появления первых authenticated/protected routes, чтобы не закреплять неправильные transport contracts.
- **P2 — follow-up**: эксплуатационные и maintenance-задачи; они не требуют перестройки архитектуры.
- Если конкретный проект не использует WebSocket, WebSocket-пункты можно исключить из его runtime scope, но это должно быть явно зафиксировано.

---

# P0 — blocking foundation issues

## P0.1 WebSocket: не публиковать небезопасный generic endpoint

**Проблема:** application message limit проверяется уже после того, как Mist/Gramps прочитали, собрали и, возможно, распаковали сообщение. Это не является ранним memory/CPU limit.

**Что сделать:**

- [ ] Убрать `/ws` echo endpoint из production routes.
- [ ] Оставить echo route только для development/integration tests либо заменить его реальным business-owned route.
- [ ] Не согласовывать `permessage-deflate`, пока нет bounded decompression.
- [ ] Не считать текущую проверку `64 KiB` достаточной защитой от oversized/compressed/fragmented input.
- [ ] Определить поддерживаемый transport API/library solution для раннего ограничения:
  - declared frame payload;
  - aggregate fragmented message;
  - connection buffer;
  - decompressed output.
- [ ] Добавить raw integration tests на oversized frame, fragmented message и compression bomb после появления такой поддержки.

**Критерий готовности:**

- В production нет публичного WS endpoint без документированных ранних limits.
- Любой оставшийся WS route имеет explicit access policy и проверенные limits до дорогой обработки.
- Compression либо запрещена, либо bounded на transport layer.

**Зависимости:** решение по публичному Mist API/версии transport library.

---

## P0.2 HTTP rate limiting: корректная client identity и fail-closed behavior

**Проблема:** за reverse proxy limiter использует IP самого proxy, поэтому все клиенты делят один bucket. При ошибке получения peer metadata limiter обходится полностью.

**Что сделать:**

- [ ] Ввести отдельную функцию получения проверенной `ClientIdentity`.
- [ ] Для прямого trusted internal traffic использовать direct peer identity.
- [ ] Для trusted reverse proxy использовать client IP из forwarded header только после проверки direct peer.
- [ ] Принять deployment contract: ingress удаляет входящие client-supplied forwarded headers и устанавливает собственные.
- [ ] Строго валидировать IPv4/IPv6 и формат forwarded chain.
- [ ] Не принимать forwarded headers от неизвестного direct peer.
- [ ] При malformed/missing client identity от trusted proxy не обходить limiter: вернуть controlled rejection либо использовать отдельный bounded fallback bucket.
- [ ] Ошибку `mist.get_connection_info` обрабатывать как failure, а не как `None -> dispatch`.

**Критерий готовности:**

- Два клиента за одним trusted proxy не делят один HTTP bucket.
- Прямой клиент не может подменить свою identity через forwarded headers.
- Ошибка peer metadata не приводит к rate-limit bypass.
- Поведение identity и trusted proxy зафиксировано тестами.

**Зависимости:** конкретная ingress topology и формат forwarded headers.

---

## P0.3 Limiter failures: безопасный application error boundary

**Проблема:** `actor.call` timeout/dead actor может завершить caller до Wisp error middleware. Тогда клиент получает raw Mist `500` вместо безопасного API response.

**Что сделать:**

- [ ] Добавить typed limiter failure, например `LimiterUnavailable`/`LimiterTimeout`.
- [ ] Перехватывать failure communication с limiter actor внутри limiter API.
- [ ] Не возвращать actor timeout как crash наружу transport boundary.
- [ ] Поместить весь dispatcher flow после создания context под единый safe boundary.
- [ ] Для HTTP mapping использовать `503 Service Unavailable` без internal details.
- [ ] Для WebSocket handshake mapping использовать собственный безопасный error response до upgrade.
- [ ] Сохранять единый request ID в response и logs.
- [ ] Проверить, что падение limiter не роняет Mist listener.

**Критерий готовности:**

- Stopped или delayed limiter даёт контролируемый `503`, а не raw `500`.
- Response не содержит stack trace, actor details или internal reason.
- Security headers и request ID сохраняются.
- Следующий request продолжает обслуживаться.

---

## P0.4 WebSocket connection capacity: lease и гарантированный release

**Проблема:** общий counter увеличивается до подтверждённого Mist upgrade, а release выполняется только в `on_close`. Failed upgrade/start может навсегда занять slot.

**Что сделать:**

- [ ] Заменить anonymous increment/decrement на reservation lease с уникальным ID.
- [ ] Передавать lease ID в connection state.
- [ ] Сделать release idempotent.
- [ ] Освобождать lease при:
  - failed `mist.websocket` result;
  - exception во время upgrade/start;
  - init timeout;
  - request/actor timeout;
  - normal/abnormal connection close.
- [ ] Не позволять повторному release освободить slot другого connection.
- [ ] Добавить тесты на 100 failed handshakes и повторный release.

**Критерий готовности:**

- Failed handshake не уменьшает доступную capacity навсегда.
- После любого failed upgrade следующий нормальный connection может занять освобождённый slot.
- Повторный cleanup безопасен.
- Отдельный connection process не роняет limiter actor или listener.

---

## P0.5 Production migrations и readiness contract

**Проблема:** production image не содержит `backend/migrations`, migration job не описан, а `/ready` проверяет только `select 1`. Backend может стать healthy до применения schema.

**Что сделать:**

- [ ] Выбрать и задокументировать один deployment contract:
  - отдельный migration image/job перед rollout; или
  - production artifact с migrations и отдельной one-shot command.
- [ ] Добавить `backend/migrations/` в нужный production artifact либо migration artifact.
- [ ] После старта pool в migration CLI вызвать bounded `pool.wait_until_ready`.
- [ ] Гарантировать остановку pool supervisor на success и failure.
- [ ] Определить, что именно означает `/ready`:
  - только DB connectivity; или
  - connectivity плюс expected schema version.
- [ ] Если `/ready` означает готовность business runtime, проверять expected migration version.
- [ ] Убрать противоречие между `docker-compose.prod.yml` и документацией об external PostgreSQL/local-infra.
- [ ] Для external DB убрать обязательную зависимость от локального `postgres` service.

**Критерий готовности:**

- Migration step выполняется до backend rollout.
- Migration error останавливает deployment.
- Backend не объявляется ready на пустой/устаревшей schema.
- `docker compose config` и documentation описывают один и тот же deployment scenario.

---

# P1 — required hardening before protected routes

## P1.1 Один request/handshake context

- [ ] Создавать один `TransportContext` на внешнем dispatcher boundary.
- [ ] Передавать его в HTTP router, WS router, rate-limit errors и error mappings.
- [ ] Не создавать новый context для одной и той же операции.
- [ ] Проверить совпадение:
  - `x-request-id`;
  - JSON `request_id`;
  - log fields;
  - WS connection correlation.

**Acceptance:** один request/handshake имеет один request ID во всех доступных наружу и диагностических представлениях.

## P1.2 Public routes без неявного session lookup

- [ ] Для `access.Public` не вызывать `session.principal`.
- [ ] `/health` и `/ready` не должны зависеть от cookie presence.
- [ ] Если нужен optional authentication, добавить отдельную explicit access policy.
- [ ] Добавить тест с произвольным cookie и проверкой отсутствия session DB lookup.

**Acceptance:** public endpoint не создаёт необязательный DB workload и liveness не меняет semantics из-за cookie.

## P1.3 Строгая WebSocket handshake validation

- [ ] Trim `Sec-WebSocket-Key`.
- [ ] Base64-decode key.
- [ ] Требовать ровно 16 decoded bytes.
- [ ] Отклонять invalid, empty и whitespace-only values до `mist.websocket`.
- [ ] Добавить positive/negative tests.

**Acceptance:** malformed RFC 6455 key получает `400` и не резервирует connection capacity.

## P1.4 Typed trusted IP configuration

- [ ] Валидировать каждый `TRUSTED_PROXY_IPS` и `TRUSTED_INTERNAL_IPS` entry при startup.
- [ ] Поддержать canonical IPv4/IPv6 representation.
- [ ] Не добавлять CIDR без реального requirement.
- [ ] Добавить tests на malformed IP, empty item и valid IPv6.

**Acceptance:** typo в production network config вызывает fail-fast, а не silent non-match.

## P1.5 Безопасная сериализация log fields

- [ ] Экранировать `\\`, `\n`, `\r`, `\t`, quotes и delimiter для каждого field.
- [ ] Предпочтительно перейти на JSON structured logging.
- [ ] Добавить тесты против log injection/multiline values.
- [ ] Не добавлять cookies, tokens, authorization headers или request bodies.

**Acceptance:** пользовательский path/user ID не может создать новую log line или подменить event/field.

## P1.6 Безопасный disabled metrics mode

- [ ] Заменить disabled metrics на отдельный variant.
- [ ] `record(Disabled, ...)` должен быть no-op.
- [ ] Не создавать dynamic Erlang atom/name/subject для disabled mode.
- [ ] `snapshot(Disabled)` должен возвращать zero snapshot либо быть явно unavailable.
- [ ] Добавить regression test на disabled mode.

**Acceptance:** no dynamic atom allocation и no mailbox growth на disabled path.

## P1.7 Migration validation и integration tests

- [ ] При загрузке migration files извлекать numeric prefix.
- [ ] Отклонять duplicate prefixes.
- [ ] Использовать parameterized pog query для history insert.
- [ ] Включённый DB integration mode должен падать при unavailable PostgreSQL.
- [ ] Запускать реальные repository migration files в isolated test database/schema.
- [ ] Проверять `schema_migrations`, tables, columns и повторный запуск.

**Acceptance:** migration tests не могут быть false green и подтверждают реальные SQL files.

---

# P2 — operational and maintenance follow-up

## P2.1 Monotonic latency

- [ ] Использовать monotonic clock для HTTP duration.
- [ ] Использовать monotonic clock для WS handshake duration.
- [ ] Wall clock оставить только для event timestamps/expiration semantics.
- [ ] Добавить regression test или injectable clock для duration calculation.

## P2.2 Metrics strategy

Выбрать один вариант:

- [ ] Добавить защищённый/internal metrics export endpoint; или
- [ ] Подключить metrics exporter; или
- [ ] Удалить пока неиспользуемую in-memory metrics abstraction и оставить structured logs.

Дополнительно:

- [ ] Не считать `SupervisorRestarted`, пока нет реального источника события.
- [ ] Не добавлять distributed metrics/Redis без конкретного requirement.

## P2.3 Session cleanup

- [ ] Добавить простую maintenance operation для expired/revoked sessions.
- [ ] Определить retention policy для revoked rows.
- [ ] Использовать существующий expiry index.
- [ ] Не добавлять отдельную job platform без необходимости.

## P2.4 Container restart policy

Выбрать один вариант:

- [ ] Добавить `restart: unless-stopped` для standalone production-like Compose; или
- [ ] Явно задокументировать, что restart выполняет внешний orchestrator.

## P2.5 Public Wisp APIs in tests

- [ ] Перевести `wisp.create_canned_connection` на public `wisp/simulate` API.
- [ ] Не использовать `@internal` Wisp API в новых tests.

## P2.6 Documentation consistency

- [ ] Обновить `docs/otp-supervision-tree.md` и SVG согласно фактическому tree.
- [ ] Исправить имя shutdown test либо добавить реальную проверку termination order.
- [ ] Обновить migration/deployment docs после выбора production migration contract.
- [ ] Зафиксировать, что HAProxy не обязателен: допустим любой trusted TLS terminator/reverse proxy.
- [ ] Документировать forwarded-header contract.

---

# Что уже можно оставить как есть

Следующие решения по результатам аудита не требуют рефакторинга:

- [x] Разделение `application`, `config`, `db`, `observability`, `ratelimit`, `transport`.
- [x] Отдельные HTTP и WebSocket transport boundaries.
- [x] Explicit route methods/resources/access policy.
- [x] Fail-fast production config для environment, secret, origins, public URL и DB budgets.
- [x] Application-level session token hashing и secure cookie attributes.
- [x] Один supervised PostgreSQL pool owner.
- [x] Transactional migration application и applied migration tracking как базовый механизм.
- [x] OTP supervision tree и Mist supervised listener.
- [x] Single-instance in-memory rate limiting как текущий допустимый scope.
- [x] Wisp 2.2.2, Mist 6.0.3, pog 4.1.0 и остальные проверенные зависимости.
- [x] Отсутствие обязательной зависимости от HAProxy и отсутствия собственного TLS certificate management.
- [x] Отсутствие fake business entities и premature Redis/distributed coordination.

---

# Recommended execution order

## Phase 1 — unblock foundation

1. [ ] Решить production scope WebSocket: отключить `/ws` или зафиксировать supported early-limit solution.
2. [ ] Исправить client identity/rate-limit fail-open.
3. [ ] Добавить typed limiter failures и top-level safety boundary.
4. [ ] Реализовать WebSocket lease cleanup.
5. [ ] Выбрать migration artifact/job contract и включить migrations в deployment path.

## Phase 2 — stabilize contracts

6. [ ] Объединить request context.
7. [ ] Убрать session lookup для public routes.
8. [ ] Усилить WS key validation.
9. [ ] Валидировать trusted IP config.
10. [ ] Исправить logger и disabled metrics.
11. [ ] Усилить migration validation/integration tests.

## Phase 3 — operational polish

12. [ ] Monotonic durations.
13. [ ] Metrics strategy.
14. [ ] Session cleanup.
15. [ ] Restart policy.
16. [ ] Public Wisp test APIs.
17. [ ] Documentation consistency.

---

# Final readiness gate

Foundation можно считать готовым к бизнес-фичам, если выполнены все условия:

- [ ] Нет публичного generic WebSocket endpoint с поздним-only message limit.
- [ ] Rate limiter не bypass-ится из-за peer/forwarded header errors.
- [ ] Limiter failures возвращаются как controlled transport responses.
- [ ] WebSocket reservations освобождаются idempotently при любом lifecycle outcome.
- [ ] Production deployment применяет migrations до readiness.
- [ ] Request ID един для одного request/handshake.
- [ ] Public routes не выполняют неявный DB session lookup.
- [ ] Production config валидирует trusted IP values.
- [ ] Logs не допускают multiline/log injection и не содержат secrets.
- [ ] `gleam format`, `gleam check` и `gleam test` проходят.
- [ ] DB integration suite в явно включённом режиме действительно подключается к PostgreSQL и падает при infrastructure failure.
- [ ] Проверены relevant HTTP/WebSocket integration tests.

## Итог

Сейчас ответ не «всё нормально» и не «нужно переписывать backend». Правильная оценка:

> Архитектурная основа хорошая и её не нужно переделывать. Но перед production-ready бизнес-фичами нужно закрыть пять P0 runtime/deployment задач. После этого оставшиеся пункты — обычный hardening и эксплуатационная доводка, а не блокирующая смена архитектуры.
