import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleeunit/should
import ratelimit/limiter
import ratelimit/policy as ratelimit_policy

pub fn http_limit_rejects_then_recovers_test() {
  let limiter = start_limiter()
  let assert Ok(Nil) = limiter.check_http(limiter, "127.0.0.1")
  let assert Ok(Nil) = limiter.check_http(limiter, "127.0.0.1")
  let assert Ok(Nil) = limiter.check_http(limiter, "127.0.0.1")
  let assert Ok(Nil) = limiter.check_http(limiter, "127.0.0.1")
  let assert Ok(Nil) = limiter.check_http(limiter, "127.0.0.1")
  let assert Error(_) = limiter.check_http(limiter, "127.0.0.1")

  process.sleep(ratelimit_policy.http_window_ms + 100)

  limiter.check_http(limiter, "127.0.0.1")
  |> should.equal(Ok(Nil))
}

pub fn websocket_connection_limit_releases_after_close_test() {
  let limiter = start_limiter()
  let assert Ok(Nil) =
    open_connections(limiter, ratelimit_policy.max_websocket_connections)
  let assert Error(limiter.ConnectionsFull) = limiter.open_websocket(limiter)

  limiter.close_websocket(limiter)
  process.sleep(ratelimit_policy.limiter_call_timeout_ms / 10)

  limiter.open_websocket(limiter)
  |> should.equal(Ok(Nil))
}

fn open_connections(
  limiter: limiter.Limiter,
  count: Int,
) -> Result(Nil, limiter.Rejection) {
  case count {
    0 -> Ok(Nil)
    _ ->
      case limiter.open_websocket(limiter) {
        Ok(Nil) -> open_connections(limiter, count - 1)
        Error(error) -> Error(error)
      }
  }
}

fn start_limiter() -> limiter.Limiter {
  let #(limiter, child) = limiter.new_child()
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start
  limiter
}
