import config/app
import config/env
import db/migrations
import db/pool
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleam/result
import logging

pub fn main() -> Nil {
  case run() {
    Ok(Nil) -> {
      logging.log(logging.Info, "Database migrations applied")
      Nil
    }
    Error(message) -> {
      logging.log(logging.Error, "Database migration failed: " <> message)
      process.send_abnormal_exit(process.self(), message)
    }
  }
}

fn run() -> Result(Nil, String) {
  use _ <- result.try(env.load())
  logging.configure()
  use config <- result.try(app.load())
  use #(postgres, postgres_child) <- result.try(pool.build(config.postgres))
  let assert Ok(started) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(postgres_child)
    |> supervisor.start
  let result = migrations.run(postgres, config.postgres)
  process.send_exit(started.pid)
  result
  |> result.map_error(error_message)
}

fn error_message(error: migrations.Error) -> String {
  case error {
    migrations.Directory(path) -> "Cannot read migrations directory: " <> path
    migrations.InvalidFilename(filename) ->
      "Invalid migration filename: " <> filename
    migrations.Read(path) -> "Cannot read migration: " <> path
    migrations.Database(message) -> "Database migration error: " <> message
  }
}
