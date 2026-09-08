import gleam/erlang/process
import gleam/int
import logging
import mist
import wisp/wisp_mist

import config/app
import config/env
import db/pool
import dependencies
import http/router

pub fn start() -> Nil {
  let assert Ok(Nil) = env.load()

  logging.configure()
  case app.load() {
    Ok(config) -> start_server(config)
    Error(message) -> panic as message
  }
}

fn start_server(config: app.AppConfig) -> Nil {
  let assert Ok(postgres) = pool.start(config.postgres)
    as "PostgreSQL connection failed"
  logging.log(logging.Info, "PostgreSQL connected")

  let dependencies = dependencies.new(config, postgres)
  let handler =
    wisp_mist.handler(
      fn(request) { router.handle(request, dependencies) },
      config.secret_key_base,
    )
  let server =
    mist.new(handler)
    |> mist.bind(config.host)
    |> mist.port(config.port)

  case mist.start(server) {
    Ok(_) -> {
      logging.log(
        logging.Info,
        "HTTP server started on port " <> int.to_string(config.port),
      )
      process.sleep_forever()
    }
    Error(_) -> Nil
  }
}
