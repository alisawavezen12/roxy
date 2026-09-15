create table if not exists users (
  id text primary key,
  dobrunia_user_id text not null unique,
  email text not null,
  first_name text,
  last_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
)
