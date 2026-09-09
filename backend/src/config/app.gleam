import config/defaults
import config/environment
import config/origins
import db/config as db_config
import envoy
import gleam/int
import gleam/result
import gleam/string

pub type AppConfig {
  AppConfig(
    host: String,
    port: Int,
    environment: environment.Environment,
    secret_key_base: String,
    origins: origins.OriginsConfig,
    postgres: db_config.PostgresConfig,
  )
}

pub fn load() -> Result(AppConfig, String) {
  use environment <- result.try(environment.load())
  let host = defaults.host
  use port_string <- result.try(load_port(environment))
  use port <- result.try(parse_port(port_string))
  use secret_key_base <- result.try(load_secret(environment))
  use origins_config <- result.try(origins.load(environment))
  use postgres_config <- result.try(db_config.load(environment))

  case string.length(secret_key_base) >= 64 {
    True ->
      Ok(AppConfig(
        host:,
        port:,
        environment:,
        secret_key_base:,
        origins: origins_config,
        postgres: postgres_config,
      ))
    False -> Error("SECRET_KEY_BASE must be at least 64 characters long")
  }
}

fn load_port(environment: environment.Environment) -> Result(String, String) {
  case environment {
    environment.Development -> Ok(int.to_string(defaults.port))
    environment.Production -> required("PORT")
  }
}

fn load_secret(environment: environment.Environment) -> Result(String, String) {
  case environment {
    environment.Development -> Ok(defaults.secret_key_base)
    environment.Production -> required("SECRET_KEY_BASE")
  }
}

fn required(name: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Ok(value)
    _ -> Error(name <> " environment variable is required in production")
  }
}

fn parse_port(value: String) -> Result(Int, String) {
  case int.parse(value) {
    Ok(port) if port > 0 && port < 65_536 -> Ok(port)
    _ -> Error("PORT must be an integer between 1 and 65535")
  }
}
