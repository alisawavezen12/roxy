alter table sessions
  add column if not exists provider_access_token bytea
