alter table sessions
  add column if not exists provider_refresh_token bytea
