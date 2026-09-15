create index if not exists oauth_states_expiry_idx
  on oauth_states (expires_at)
