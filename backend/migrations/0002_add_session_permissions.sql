alter table sessions
  add column if not exists permissions text[] not null default '{}';
