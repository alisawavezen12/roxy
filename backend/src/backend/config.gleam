import envoy
import gleam/int
import gleam/result
import gleam/erlang/process
import pog

pub type Config {
  Config(
    host: String,
    port: Int,
    secret_key_base: String,
    database_url: String,
  )
}

pub fn load() -> Config {
  Config(
    host: optional("HOST", "127.0.0.1"),
    port: optional("PORT", "8080") |> int.parse |> result.unwrap(8080),
    secret_key_base: required("SECRET_KEY_BASE"),
    database_url: required("DATABASE_URL"),
  )
}

pub fn database_config(
  config: Config,
  pool_name: process.Name(pog.Message),
) -> pog.Config {
  let assert Ok(database) = pog.url_config(pool_name, config.database_url)
  pog.pool_size(database, 10)
}

fn required(name: String) -> String {
  case envoy.get(name) {
    Ok("") -> panic as { name <> " must not be empty" }
    Ok(value) -> value
    Error(_) -> panic as { name <> " is required" }
  }
}

fn optional(name: String, fallback: String) -> String {
  envoy.get(name) |> result.unwrap(fallback)
}
