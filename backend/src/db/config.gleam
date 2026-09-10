import config/environment.{type Environment, Development, Production}
import db/defaults
import envoy
import gleam/int
import gleam/result

pub type PostgresConfig {
  PostgresConfig(
    url: String,
    pool_size: Int,
    query_timeout: Int,
    statement_timeout: Int,
    lock_timeout: Int,
    transaction_timeout: Int,
    idle_in_transaction_timeout: Int,
  )
}

pub fn load(environment: Environment) -> Result(PostgresConfig, String) {
  case environment {
    Development ->
      Ok(PostgresConfig(
        url: defaults.url,
        pool_size: defaults.pool_size,
        query_timeout: defaults.query_timeout,
        statement_timeout: defaults.statement_timeout,
        lock_timeout: defaults.lock_timeout,
        transaction_timeout: defaults.transaction_timeout,
        idle_in_transaction_timeout: defaults.idle_in_transaction_timeout,
      ))
    Production -> {
      use url <- result.try(required("DATABASE_URL"))
      use pool_size <- result.try(required_setting("DATABASE_POOL_SIZE"))
      use query_timeout <- result.try(required_setting(
        "DATABASE_QUERY_TIMEOUT_MS",
      ))
      use statement_timeout <- result.try(required_setting(
        "DATABASE_STATEMENT_TIMEOUT_MS",
      ))
      use lock_timeout <- result.try(required_setting("DATABASE_LOCK_TIMEOUT_MS"))
      use transaction_timeout <- result.try(required_setting(
        "DATABASE_TRANSACTION_TIMEOUT_MS",
      ))
      use idle_in_transaction_timeout <- result.try(required_setting(
        "DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS",
      ))
      use _ <- result.try(validate_budgets(
        statement_timeout,
        lock_timeout,
        transaction_timeout,
        idle_in_transaction_timeout,
      ))
      Ok(PostgresConfig(
        url:,
        pool_size:,
        query_timeout:,
        statement_timeout:,
        lock_timeout:,
        transaction_timeout:,
        idle_in_transaction_timeout:,
      ))
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

fn validate_budgets(
  statement_timeout: Int,
  lock_timeout: Int,
  transaction_timeout: Int,
  idle_in_transaction_timeout: Int,
) -> Result(Nil, String) {
  case lock_timeout <= statement_timeout {
    False -> Error("DATABASE_LOCK_TIMEOUT_MS must not exceed DATABASE_STATEMENT_TIMEOUT_MS")
    True -> case statement_timeout <= transaction_timeout {
      False -> Error("DATABASE_STATEMENT_TIMEOUT_MS must not exceed DATABASE_TRANSACTION_TIMEOUT_MS")
      True -> case idle_in_transaction_timeout <= transaction_timeout {
        False -> Error("DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS must not exceed DATABASE_TRANSACTION_TIMEOUT_MS")
        True -> Ok(Nil)
      }
    }
  }
}
