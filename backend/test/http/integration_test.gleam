import gleam/erlang/process

import gleam/http/request
import gleam/http/response.{type Response}

import gleam/httpc
import gleam/int
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

import gleeunit/should
import http/protocol/api_errors
import http/request_context
import mist
import wisp
import wisp/wisp_mist

pub fn crash_does_not_stop_http_server_test() {
  let port = 18_081
  let server = fn() {
    let handler = fn(request: wisp.Request) {
      case request.path {
        "/test/crash" ->
          api_errors.response(
            500,
            "internal",
            "Internal server error",
            request_context.new(),
          )
        "/health" -> wisp.ok()
        _ -> wisp.not_found()
      }
    }
    let builder =
      wisp_mist.handler(
        handler,
        "test-secret-key-base-that-is-long-enough-for-wisp",
      )
      |> mist.new
      |> mist.bind("127.0.0.1")
      |> mist.port(port)
    mist.start(builder)
  }

  let assert Ok(started) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(supervision.supervisor(server))
    |> supervisor.start

  process.sleep(100)

  let crash_response = get(port, "/test/crash")
  crash_response.status
  |> should.equal(500)

  let health_response = get(port, "/health")
  health_response.status
  |> should.equal(200)

  process.send_exit(started.pid)
}

fn get(port: Int, path: String) -> Response(String) {
  let assert Ok(request) =
    request.to("http://127.0.0.1:" <> int.to_string(port) <> path)
  let assert Ok(response) = httpc.send(request)
  response
}
