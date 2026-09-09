import config/environment
import db/config as db_config
import db/defaults
import db/pool
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleeunit/should
import pog

pub fn postgres_pool_exhaustion_integration_test() {
  case environment.load() {
    Ok(environment.Development) -> run_integration_test(defaults.url)
    _ -> Nil
  }
}

fn run_integration_test(url: String) {
  let config = db_config.PostgresConfig(url:, pool_size: 1, query_timeout: 100)
  let assert Ok(#(connection, child)) = pool.build(config)
  let assert Ok(started) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start

  let assert Ok(_) = pool.wait_until_ready(connection, config.query_timeout, 20)

  let reply = process.new_subject()
  let _worker =
    process.spawn_unlinked(fn() {
      process.send(
        reply,
        pool.execute(connection, "select pg_sleep(0.2)", 1000),
      )
    })

  process.sleep(50)

  let second_query = pool.execute(connection, "select 1", 10)
  case second_query {
    Error(pog.ConnectionUnavailable) | Error(pog.QueryTimeout) -> Nil
    _ -> panic as "pool exhaustion must reject the second checkout"
  }

  let assert Ok(first_query_result) = process.receive(reply, 2000)
  first_query_result
  |> should.equal(Ok(pog.Returned(1, [Nil])))

  process.send_exit(started.pid)
}
