import config/environment.{type Environment, Development, Production}
import db/defaults
import envoy
import gleam/int
import gleam/result

pub type PostgresConfig {
  PostgresConfig(url: String, pool_size: Int, query_timeout: Int)
}

pub fn load(environment: Environment) -> Result(PostgresConfig, String) {
  case environment {
    Development ->
      Ok(PostgresConfig(
        url: defaults.url,
        pool_size: defaults.pool_size,
        query_timeout: defaults.query_timeout,
      ))
    Production -> {
      use url <- result.try(required("DATABASE_URL"))
      use pool_size <- result.try(required_setting("DATABASE_POOL_SIZE"))
      use query_timeout <- result.try(required_setting(
        "DATABASE_QUERY_TIMEOUT_MS",
      ))
      Ok(PostgresConfig(url:, pool_size:, query_timeout:))
    }
  }
}

fn required(name: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Ok(value)
    _ -> Error(name <> " environment variable is required in production")
  }
}

fn required_setting(name: String) -> Result(Int, String) {
  use value <- result.try(required(name))
  parse_positive(name, value)
}

fn parse_positive(name: String, value: String) -> Result(Int, String) {
  case int.parse(value) {
    Ok(number) if number > 0 -> Ok(number)
    _ -> Error(name <> " must be a positive integer")
  }
}
