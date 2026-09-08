import db/config as db_config
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleam/result
import pog

pub fn start(
  config: db_config.PostgresConfig,
) -> Result(pog.Connection, String) {
  let pool_name = process.new_name("roxy_postgres")
  use pool_config <- result.try(
    pog.url_config(pool_name, config.url)
    |> result.replace_error("Invalid DATABASE_URL"),
  )

  let pool_config =
    pool_config
    |> pog.pool_size(config.pool_size)

  let pool_child = pog.supervised(pool_config)
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(pool_child)
    |> supervisor.start

  let connection = pog.named_connection(pool_name)
  wait_until_ready(connection, 10)
  |> result.replace(connection)
}

fn wait_until_ready(
  connection: pog.Connection,
  attempts: Int,
) -> Result(Nil, String) {
  case pog.query("select 1") |> pog.execute(connection) {
    Ok(_) -> Ok(Nil)
    Error(_) if attempts > 0 -> {
      process.sleep(100)
      wait_until_ready(connection, attempts - 1)
    }
    Error(_) -> Error("PostgreSQL connection failed")
  }
}
