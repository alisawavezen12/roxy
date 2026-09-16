alter table users
  drop column if exists external_created_at,
  drop column if exists external_updated_at
