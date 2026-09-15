alter table users
  add column if not exists external_created_at timestamptz,
  add column if not exists external_updated_at timestamptz
