create index if not exists sessions_provider_session_id_idx
  on sessions (provider_session_id)
  where provider_session_id is not null
