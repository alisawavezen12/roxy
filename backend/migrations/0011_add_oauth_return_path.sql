alter table oauth_states
  add column if not exists return_path text not null default '/'
