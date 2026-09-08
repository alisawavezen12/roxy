import gleam/erlang/process
import mist

import config
import http/router

pub fn main() -> Nil {
  let server =
    mist.new(router.handle)
    |> mist.bind(config.host)
    |> mist.port(config.port)

  case mist.start(server) {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
