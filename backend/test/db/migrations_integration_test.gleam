import config/environment
import db/config as db_config
import db/migrations
import db/pool
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor

import simplifile

pub fn migrations_run_empty_and_again_test() {
  case environment.load() {
    Ok(environment.Development) -> run_with_database()
    Error(_) | Ok(environment.Production) -> Nil
  }
}

fn run_with_database() -> Nil {
  let directory = "test_tmp_sql_migrations"
  let assert Ok(Nil) = migrations.ensure_directory(directory)
  let config =
    db_config.PostgresConfig(
      url: "postgres://roxy:roxy@postgres:5432/roxy",
      pool_size: 1,
      query_timeout: 1000,
      statement_timeout: 800,
      lock_timeout: 100,
      transaction_timeout: 2000,
      idle_in_transaction_timeout: 500,
    )
  case pool.build(config) {
    Error(_) -> Nil
    Ok(#(connection, child)) -> {
      let assert Ok(started) =
        supervisor.new(supervisor.OneForOne)
        |> supervisor.add(child)
        |> supervisor.start
      case pool.wait_until_ready(connection, config.query_timeout, 20) {
        Error(_) -> process.send_exit(started.pid)
        Ok(Nil) -> {
          let assert Ok(Nil) =
            migrations.run_from_directory(connection, config, directory)
          let assert Ok(Nil) =
            migrations.run_from_directory(connection, config, directory)
          process.send_exit(started.pid)
        }
      }
      let _ = simplifile.delete(directory)
      Nil
    }
  }
}
