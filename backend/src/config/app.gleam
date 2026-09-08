import envoy
import gleam/int
import gleam/result
import gleam/string

pub type Environment {
  Development
  Production
}

pub type Config {
  Config(
    host: String,
    port: Int,
    environment: Environment,
    secret_key_base: String,
  )
}

pub fn load() -> Result(Config, String) {
  let host = "0.0.0.0"
  use port_string <- result.try(required("PORT", "8080"))
  use port <- result.try(parse_port(port_string))
  use environment <- result.try(load_environment())
  use secret_key_base <- result.try(required("SECRET_KEY_BASE", ""))

  case string.length(secret_key_base) >= 64 {
    True -> Ok(Config(host:, port:, environment:, secret_key_base:))
    False -> Error("SECRET_KEY_BASE must be at least 64 characters long")
  }
}

fn required(name: String, default: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Ok(value)
    _ if default != "" -> Ok(default)
    _ -> Error(name <> " environment variable is required")
  }
}

fn load_environment() -> Result(Environment, String) {
  let value = required("APP_ENV", "development")
  case value {
    Ok("development") -> Ok(Development)
    Ok("production") -> Ok(Production)
    Ok(environment) ->
      Error(
        "APP_ENV must be either development or production, got: " <> environment,
      )
    Error(error) -> Error(error)
  }
}

fn parse_port(value: String) -> Result(Int, String) {
  case int.parse(value) {
    Ok(port) if port > 0 && port < 65_536 -> Ok(port)
    _ -> Error("PORT must be an integer between 1 and 65535")
  }
}
