import application/messages
import db/config as db_config
import gleam/erlang/process
import gleam/int
import gleam/result
import pog

pub fn build(
  config: db_config.PostgresConfig,
) -> Result(#(pog.Connection, _), String) {
  let pool_name = process.new_name("roxy_postgres")
  use pool_config <- result.try(
    pog.url_config(pool_name, config.url)
    |> result.replace_error(messages.invalid_database_url),
  )

  let pool_config =
    pool_config
    |> pog.pool_size(config.pool_size)
    |> pog.connection_parameter(
      "statement_timeout",
      int.to_string(config.statement_timeout),
    )
    |> pog.connection_parameter(
      "lock_timeout",
      int.to_string(config.lock_timeout),
    )
    |> pog.connection_parameter(
      "transaction_timeout",
      int.to_string(config.transaction_timeout),
    )
    |> pog.connection_parameter(
      "idle_in_transaction_session_timeout",
      int.to_string(config.idle_in_transaction_timeout),
    )
  let connection = pog.named_connection(pool_name)
  let pool_child = pog.supervised(pool_config)

  Ok(#(connection, pool_child))
}

pub fn execute(
  connection: pog.Connection,
  sql: String,
  timeout: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  pog.query(sql)
  |> pog.timeout(timeout)
  |> pog.execute(connection)
}

pub fn wait_until_ready(
  connection: pog.Connection,
  timeout: Int,
  attempts: Int,
) -> Result(Nil, String) {
  case execute(connection, "select 1", timeout) {
    Ok(_) -> Ok(Nil)
    Error(_) if attempts > 0 -> {
      process.sleep(100)
      wait_until_ready(connection, timeout, attempts - 1)
    }
    Error(_) -> Error(messages.postgres_connection_failed)
  }
}
