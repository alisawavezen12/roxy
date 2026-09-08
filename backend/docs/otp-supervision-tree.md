# Roxy OTP supervision tree

The backend startup is owned by `src/roxy_application.gleam`:

1. Load `.env` and application/database configuration.
2. Build one named `pog.Connection` and the corresponding `pog.supervised` pool child specification.
3. Build `Dependencies` once from the application config and named connection.
4. Build the Wisp/Mist handler closure with that `Dependencies` value.
5. Build the direct Mist child with `handler |> mist.new |> mist.bind |> mist.port |> mist.supervised`.
6. Start one root `static_supervisor` with `RestForOne` and restart tolerance `intensity: 3, period: 10`, adding PostgreSQL before Mist.
7. Keep the BEAM entrypoint alive while the linked root supervisor owns the application tree.

## Child order and policy

The root child order is:

1. PostgreSQL pool: `pog.supervised(pool_config)`.
2. HTTP server: `mist.supervised(builder)`.

Mist 6's `mist.supervised(builder)` starts the Mist supervisor child. The Wisp router receives the same startup-created `Dependencies` value through the handler closure; there is no global mutable configuration or database state.

The root supervisor is configured with `RestForOne` and `restart_tolerance(3, 10)`:

- **PostgreSQL pool process failure** restarts the pool and the later Mist child.
- **PostgreSQL server outage** does not necessarily terminate the pool process: `pog` can keep the pool alive and retry/reconnect, while queries fail until PostgreSQL recovers.
- **Mist supervisor failure** restarts only Mist. A failure of an internal Mist worker is handled first by Mist's own supervision tree; the root sees it only if the Mist supervisor itself terminates.
- More than three restarts in ten seconds terminates the root supervisor instead of allowing an infinite crash loop.

## Verified child failure behavior

`test/otp/supervision_test.gleam` contains two levels of verification:

- a permanent child restart test;
- a concrete `RestForOne` test with fake DB and HTTP children. Killing DB changes both PIDs; killing HTTP changes only the HTTP PID.

These are OTP policy tests, not a full production DB/Mist failure integration test.

## Graceful shutdown

The application tree owns both long-lived children:

- `pog.supervised(pool_config)` owns the PostgreSQL pool;
- `mist.supervised(builder)` owns Mist's listener/factory supervisors.

When the root supervisor receives OTP shutdown, it stops children in reverse order: Mist first, then PostgreSQL. This stops HTTP before PostgreSQL, so no new HTTP work can depend on a database pool that has already been shut down. Mist 6 exposes the supervised startup API used here; no separate public `mist.stop` function is required for this OTP-owned shutdown path.

This is graceful at the OTP supervision boundary. Active client requests are governed by Mist's own child shutdown semantics and are not separately integration-tested yet.

Open `otp-supervision-tree.drawio` in draw.io for the editable architecture diagram.

The requested PNG preview could not be generated in this environment because the draw.io Desktop CLI is not installed. The `.drawio` source remains editable; export it with draw.io Desktop or diagrams.net.
