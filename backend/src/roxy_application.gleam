import application/dependencies
import config/app
import config/env
import db/pool
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import logging
import mist
import ratelimit/limiter
import wisp/wisp_mist

import transport/dispatcher
import transport/http/router as http_router

pub fn start() -> Nil {
  let assert Ok(Nil) = env.load()
  logging.configure()

  let assert Ok(config) = app.load()
  let assert Ok(#(postgres, postgres_child)) = pool.build(config.postgres)
  let #(rate_limiter, rate_limiter_child) = limiter.new_child()
  let dependencies = dependencies.new(config, postgres, rate_limiter)
  let http_handler =
    wisp_mist.handler(
      fn(request) { http_router.handle(request, dependencies) },
      config.secret_key_base,
    )
  let handler = fn(request) {
    dispatcher.handle(request, dependencies, http_handler)
  }
  let http_child =
    handler
    |> mist.new
    |> mist.bind(config.host)
    |> mist.port(config.port)
    |> mist.supervised

  logging.log(logging.Info, "Starting Roxy supervision tree")

  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.restart_tolerance(3, 10)
    |> supervisor.add(postgres_child)
    |> supervisor.add(rate_limiter_child)
    |> supervisor.add(http_child)
    |> supervisor.start

  // The root supervisor is linked to this process. Keep the BEAM entrypoint
  // alive so it remains the owner of the application's supervision tree.
  process.sleep_forever()
}
