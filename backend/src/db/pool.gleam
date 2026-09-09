import db/config as db_config
import gleam/erlang/process
import gleam/result
import pog

pub fn build(
  config: db_config.PostgresConfig,
) -> Result(#(pog.Connection, _), String) {
  let pool_name = process.new_name("roxy_postgres")
  use pool_config <- result.try(
    pog.url_config(pool_name, config.url)
    |> result.replace_error("Invalid DATABASE_URL"),
  )

  let pool_config = pog.pool_size(pool_config, config.pool_size)
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
    Error(_) -> Error("PostgreSQL connection failed")
  }
}
