create table if not exists oauth_states (
  state_hash bytea primary key,
  binding_hash bytea not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
)
