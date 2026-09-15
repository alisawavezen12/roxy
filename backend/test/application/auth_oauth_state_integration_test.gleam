import application/services/auth/oauth_state
import config/environment
import db/config as db_config
import db/defaults
import db/migrations
import db/pool
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleeunit/should

pub fn oauth_state_is_bound_one_time_and_expiring_integration_test() {
  case environment.load() {
    Ok(environment.Development) -> run_with_database()
    _ -> Nil
  }
}

fn run_with_database() -> Nil {
  let config =
    db_config.PostgresConfig(
      url: defaults.url,
      pool_size: 1,
      query_timeout: 1000,
      statement_timeout: 800,
      lock_timeout: 100,
      transaction_timeout: 2000,
      idle_in_transaction_timeout: 500,
    )
  case pool.build(config) {
    Error(_) -> Nil
    Ok(#(connection, child)) -> {
      let assert Ok(started) =
        supervisor.new(supervisor.OneForOne)
        |> supervisor.add(child)
        |> supervisor.start
      case pool.wait_until_ready(connection, config.query_timeout, 20) {
        Error(_) -> process.send_exit(started.pid)
        Ok(Nil) -> {
          let assert Ok(Nil) = migrations.run(connection, config)
          let assert Ok(#(state, binding)) =
            oauth_state.create(
              connection,
              600,
              "/user/example?tab=posts",
              config.query_timeout,
            )
          let assert Ok(oauth_state.NotFound) =
            oauth_state.consume(
              connection,
              state,
              "wrong-binding",
              config.query_timeout,
            )
          let assert Ok(oauth_state.ReturnTo(return_path)) =
            oauth_state.consume(
              connection,
              state,
              binding,
              config.query_timeout,
            )
          return_path |> should.equal("/user/example?tab=posts")
          let assert Ok(oauth_state.NotFound) =
            oauth_state.consume(
              connection,
              state,
              binding,
              config.query_timeout,
            )
          let assert Ok(#(expired_state, expired_binding)) =
            oauth_state.create(connection, -1, "/", config.query_timeout)
          let assert Ok(oauth_state.NotFound) =
            oauth_state.consume(
              connection,
              expired_state,
              expired_binding,
              config.query_timeout,
            )
          process.send_exit(started.pid)
        }
      }
    }
  }
}
