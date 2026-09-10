import application/dependencies
import config/app
import config/environment
import config/origins
import config/session
import config/transport
import db/config as postgres_config_module
import gleam/erlang/process

import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/list

import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/string
import gleeunit/should
import mist
import observability/metrics
import pog
import ratelimit/limiter

import transport/dispatcher
import transport/http/router as http_router
import transport/websocket/client
import wisp/wisp_mist

const origin = "http://localhost:1234"

pub fn connect_echo_ping_close_test() {
  let port = 18_082
  let server = start_server(port)
  let assert Ok(connection) = client.connect(websocket_url(port), origin)

  let assert Ok(Nil) = client.send_text(connection, "hello")
  client.receive_frame(connection, 2000)
  |> should.equal(Ok(client.Text("hello")))

  let assert Ok(Nil) = client.send_ping(connection, <<"heartbeat":utf8>>)
  client.receive_frame(connection, 2000)
  |> should.equal(Ok(client.Pong(<<"heartbeat":utf8>>)))

  client.close(connection)
  process.sleep(20)

  get(port, "/health").status
  |> should.equal(200)

  process.send_exit(server.pid)
}

pub fn oversized_message_closes_only_connection_test() {
  let port = 18_083
  let server = start_server(port)
  let assert Ok(connection) = client.connect(websocket_url(port), origin)

  let assert Ok(Nil) = client.send_text(connection, oversized_message())
  let assert Error(_) = client.receive_frame(connection, 2000)

  get(port, "/health").status
  |> should.equal(200)

  let assert Ok(second_connection) = client.connect(websocket_url(port), origin)
  let assert Ok(Nil) = client.send_text(second_connection, "ok")
  client.receive_frame(second_connection, 2000)
  |> should.equal(Ok(client.Text("ok")))

  client.close(second_connection)
  process.send_exit(server.pid)
}

pub fn disallowed_origin_cannot_connect_test() {
  let port = 18_084
  let server = start_server(port)

  let assert Error(_) =
    client.connect(websocket_url(port), "http://localhost:4321")

  get(port, "/health").status
  |> should.equal(200)

  process.send_exit(server.pid)
}

pub fn invalid_websocket_method_returns_405_test() {
  let port = 18_085
  let server = start_server(port)
  let response = websocket_http_request(port, http.Post, origin)

  response.status
  |> should.equal(405)

  response.body
  |> string.contains("method_not_allowed")
  |> should.equal(True)

  list.key_find(response.headers, "allow")
  |> should.equal(Ok("GET"))

  process.send_exit(server.pid)
}

pub fn malformed_websocket_handshake_returns_400_test() {
  let port = 18_086
  let server = start_server(port)
  let response = websocket_http_request(port, http.Get, origin)

  response.status
  |> should.equal(400)

  response.body
  |> string.contains("invalid_input")
  |> should.equal(True)

  process.send_exit(server.pid)
}

fn start_server(port: Int) -> actor.Started(supervisor.Supervisor) {
  let dependencies = test_dependencies(port)
  let http_handler =
    wisp_mist.handler(
      fn(request) { http_router.handle(request, dependencies) },
      dependencies.config.secret_key_base,
    )
  let handler = fn(request) {
    dispatcher.handle(request, dependencies, http_handler)
  }
  let server = fn() {
    handler
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(port)
    |> mist.start
  }

  let assert Ok(started) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(supervision.supervisor(server))
    |> supervisor.start

  process.sleep(100)
  started
}

fn test_dependencies(port: Int) -> dependencies.Dependencies {
  let config =
    app.AppConfig(
      host: "127.0.0.1",
      port:,
      environment: environment.Development,
      secret_key_base: "test-secret-key-base-that-is-long-enough-for-wisp",
      origins: origins.OriginsConfig(allowed: [origin]),
      session: session.SessionConfig(ttl_seconds: 86_400, cookie_secure: False),
      transport: transport.TransportConfig(
        public_base_url: "http://localhost:8080",
        trusted_proxy_ips: [],
        trusted_internal_ips: [],
      ),
      postgres: postgres_config_module.PostgresConfig(
        url: "postgres://test",
        pool_size: 1,
        query_timeout: 1000,
      ),
    )
  dependencies.new(
    config,
    pog.named_connection(process.new_name("test_pool")),
    limiter_for_test(),
    metrics_for_test(),
  )
}

fn get(port: Int, path: String) -> Response(String) {
  let assert Ok(request) =
    request.to("http://127.0.0.1:" <> int.to_string(port) <> path)
  let assert Ok(response) = httpc.send(request)
  response
}

fn websocket_http_request(
  port: Int,
  method: http.Method,
  origin: String,
) -> Response(String) {
  let assert Ok(request) =
    request.to("http://127.0.0.1:" <> int.to_string(port) <> "/ws")
  let request =
    request
    |> request.set_method(method)
    |> request.set_header("origin", origin)
  let assert Ok(response) = httpc.send(request)
  response
}

fn oversized_message() -> String {
  string.repeat("x", 65_537)
}

fn metrics_for_test() -> metrics.Metrics {
  let #(metrics_value, child) = metrics.new_child()
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start
  metrics_value
}

fn limiter_for_test() -> limiter.Limiter {
  let #(rate_limiter, child) = limiter.new_child()
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start
  rate_limiter
}

fn websocket_url(port: Int) -> String {
  "ws://127.0.0.1:" <> int.to_string(port) <> "/ws"
}
