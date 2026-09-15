# PostgreSQL database

## Development access

The development Compose override publishes PostgreSQL only on the host loopback
interface:

```text
127.0.0.1:5433 -> postgres:5432
```

It is available to local tools such as pgAdmin, but it is not exposed on the
LAN and is not published by the production Compose configuration.

### pgAdmin connection

Use the values from the development Compose configuration:

| Field | Value |
|---|---|
| Host name/address | `127.0.0.1` |
| Port | `5433` |
| Maintenance database | `roxy` |
| Username | `roxy` |
| Password | `roxy` |

In pgAdmin, tables are located under:

```text
Servers → Roxy → Databases → roxy → Schemas → public → Tables
```

The table context menu contains **View/Edit Data → All Rows**.

### Command-line access

No local PostgreSQL installation is required:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec postgres psql -U roxy -d roxy
```

Useful `psql` commands:

```text
\dt                 list tables
\d users            describe users
\d sessions         describe sessions
\d oauth_states     describe OAuth state storage
\q                  exit
```

## Current tables

### `users`

Local user profiles linked to Dobrunia Auth.

| Column | Purpose |
|---|---|
| `id` | Local user ID; currently equal to the Dobrunia user ID |
| `dobrunia_user_id` | Stable external identity, unique |
| `email` | Current email from Dobrunia Auth |
| `first_name`, `last_name` | Optional profile names |
| `avatar_url` | Optional avatar URL |
| `created_at`, `updated_at` | Local timestamps |

On each successful OAuth login, the user is inserted or their profile fields
are updated by external identity.

### `sessions`

Opaque Roxy browser sessions.

| Column | Purpose |
|---|---|
| `token_hash` | SHA-256 hash of the browser session token; raw token is never stored |
| `user_id` | Authenticated local user |
| `permissions` | Local permissions snapshot |
| `expires_at`, `revoked`, `created_at` | Session lifecycle |
| `provider_session_id` | Dobrunia Auth session ID |
| `provider_access_token` | AES-256-GCM encrypted provider access token |
| `provider_refresh_token` | AES-256-GCM encrypted rotating refresh token |

The encrypted token columns are binary and are not intended to be edited in
pgAdmin.

### `oauth_states`

Short-lived OAuth CSRF and return-navigation state.

| Column | Purpose |
|---|---|
| `state_hash` | Hash of the one-time OAuth `state` value |
| `binding_hash` | Hash of the matching HttpOnly cookie value |
| `return_path` | Validated frontend URL to restore after callback |
| `expires_at`, `created_at` | Short lifetime and creation time |

A valid row is deleted atomically when the callback consumes it.

### `schema_migrations`

Tracks every applied migration by version so migrations are idempotent.

## Safe inspection queries

```sql
select id, email, first_name, last_name, created_at, updated_at
from users
order by created_at desc;

select user_id, provider_session_id, expires_at, revoked, created_at
from sessions
order by created_at desc;

select return_path, expires_at, created_at
from oauth_states
order by created_at desc;

select version, applied_at
from schema_migrations
order by version;
```

Avoid selecting or exporting `provider_access_token`,
`provider_refresh_token`, and `token_hash` unless you are specifically debugging
the encrypted storage format.
