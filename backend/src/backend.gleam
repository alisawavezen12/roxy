import backend/web
import envoy
import gleam/erlang/process
import gleam/int
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let pool_name = process.new_name("pog")
  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(pog.supervised(database_config(pool_name)))
    |> supervisor.start

  let static_directory = case wisp.priv_directory("backend") {
    Ok(priv) -> priv <> "/static"
    Error(_) -> "priv/static"
  }

  let context =
    web.Context(db: pog.named_connection(pool_name), static_directory:)

  let assert Ok(_) =
    web.handle_request(_, context)
    |> wisp_mist.handler(secret_key_base())
    |> mist.new
    |> mist.bind(host())
    |> mist.port(port())
    |> mist.start

  process.sleep_forever()
}

fn database_config(pool_name: process.Name(pog.Message)) -> pog.Config {
  let url = require_env("DATABASE_URL")
  let assert Ok(config) = pog.url_config(pool_name, url)
  config
  |> pog.pool_size(10)
}

fn secret_key_base() -> String {
  envoy.get("SECRET_KEY_BASE")
  |> result.unwrap(
    "dev-only-secret-key-base-change-me-please-not-for-prod-xxxx",
  )
}

fn host() -> String {
  envoy.get("HOST")
  |> result.unwrap("127.0.0.1")
}

fn port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}

fn require_env(name: String) -> String {
  case envoy.get(name) {
    Ok(value) -> value
    Error(_) -> panic as { name <> " is required" }
  }
}
