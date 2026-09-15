alter table sessions
  add constraint sessions_user_id_fkey
  foreign key (user_id) references users (id) on delete cascade
