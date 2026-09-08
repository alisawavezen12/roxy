import gleam/erlang/process
import mist
import wisp/wisp_mist

import config/app
import config/env
import http/router

pub fn start() -> Nil {
  let assert Ok(Nil) = env.load()

  case app.load() {
    Ok(config) -> start_server(config)
    Error(message) -> panic as message
  }
}

fn start_server(config: app.Config) -> Nil {
  let handler = wisp_mist.handler(router.handle, config.secret_key_base)
  let server =
    mist.new(handler)
    |> mist.bind(config.host)
    |> mist.port(config.port)

  case mist.start(server) {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
