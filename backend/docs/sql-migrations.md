# SQL migrations

Versioned SQL migrations belong in:

```text
backend/migrations/
```

The directory may remain empty. No placeholder migration is required.

## Naming

Use a lexically sortable numeric version followed by `.sql`:

```text
0001_create_posts.sql
0002_add_post_indexes.sql
```

The version prefix must be unique and the full filename should describe the schema change. Files are applied in lexical filename order.

Only `.sql` files are considered migrations. Invalid `.sql` filenames fail the migration command; other files are ignored.

## Apply migrations

From the repository root in the development Docker setup:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml run --rm backend gleam run -m backend_migrations
```

The command uses the existing `DATABASE_URL`/development PostgreSQL configuration and the existing `pog` pool. The backend runtime does not run migrations during startup or while handling HTTP requests.

Applied versions are stored in PostgreSQL in:

```text
schema_migrations(version, applied_at)
```

Each migration and its history record are committed in one PostgreSQL transaction. A failed migration is rolled back and is not recorded as applied.
