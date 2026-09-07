import backend/config
import backend/middleware
import backend/routes
import backend/web
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  let config = config.load()
  wisp.configure_logger()

  let pool_name = process.new_name("pog")
  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(pog.supervised(config.database_config(config, pool_name)))
    |> supervisor.start

  let static_directory = case wisp.priv_directory("backend") {
    Ok(priv) -> priv <> "/static"
    Error(_) -> "priv/static"
  }

  let context =
    web.Context(db: pog.named_connection(pool_name), static_directory:)

  let assert Ok(_) =
    middleware.apply(_, static_directory, fn(req) {
      routes.dispatch(req, context)
    })
    |> wisp_mist.handler(config.secret_key_base)
    |> mist.new
    |> mist.bind(config.host)
    |> mist.port(config.port)
    |> mist.start

  process.sleep_forever()
}
