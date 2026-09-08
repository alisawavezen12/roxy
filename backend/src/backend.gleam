import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response
import mist

import config

pub fn main() -> Nil {
  let handler = fn(_request: Request(mist.Connection)) {
    response.new(200)
    |> response.prepend_header("content-type", "text/plain; charset=utf-8")
    |> response.set_body(
      mist.Bytes(bytes_tree.from_string("Roxy backend is alive")),
    )
  }

  let server =
    mist.new(handler)
    |> mist.bind(config.host)
    |> mist.port(config.port)

  case mist.start(server) {
    Ok(_) -> process.sleep_forever()
    Error(_) -> Nil
  }
}
