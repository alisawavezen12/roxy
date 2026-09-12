import application/dependencies
import config/app
import config/defaults as config_defaults
import config/environment
import config/origins
import config/session
import config/transport
import db/config as postgres_config_module
import db/defaults as db_defaults
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/string
import gleeunit
import gleeunit/should
import observability/metrics
import pog
import ratelimit/limiter

import shared/api/error as api_error
import transport/http/protocol/status
import transport/http/router
import wisp

pub fn main() {
  gleeunit.main()
}

fn test_dependencies() -> dependencies.Dependencies {
  let config =
    app.AppConfig(
      host: config_defaults.host,
      port: config_defaults.port,
      environment: environment.Development,
      secret_key_base: "test-secret-key-base-that-is-long-enough-for-wisp",
      origins: origins.OriginsConfig(allowed: ["http://localhost:1234"]),
      session: session.SessionConfig(
        ttl_seconds: session.default_ttl_seconds,
        cookie_secure: False,
      ),
      transport: transport.TransportConfig(
        public_base_url: "http://localhost:8080",
        trusted_proxy_ips: [],
        trusted_internal_ips: [],
      ),
      postgres: postgres_config(),
    )
  dependencies.new(
    config,
    pog.named_connection(process.new_name("test_pool")),
    limiter_for_test(),
    metrics_for_test(),
  )
}

fn limiter_for_test() -> limiter.Limiter {
  let #(rate_limiter, child) = limiter.new_child()
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start
  rate_limiter
}

fn metrics_for_test() -> metrics.Metrics {
  let #(metrics_value, child) = metrics.new_child()
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start
  metrics_value
}

fn postgres_config() -> postgres_config_module.PostgresConfig {
  postgres_config_module.PostgresConfig(
    url: "postgres://test",
    pool_size: 1,
    query_timeout: db_defaults.query_timeout,
    statement_timeout: db_defaults.statement_timeout,
    lock_timeout: db_defaults.lock_timeout,
    transaction_timeout: db_defaults.transaction_timeout,
    idle_in_transaction_timeout: db_defaults.idle_in_transaction_timeout,
  )
}

pub fn health_response_contains_server_request_id_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/health")
    |> request.set_header("x-request-id", "client-id")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  let request_id = request_id_header(response)
  let assert "req_" <> _ = request_id
  let assert False = request_id == "client-id"
}

fn request_id_header(response: wisp.Response) -> String {
  let assert Ok(request_id) = list.key_find(response.headers, "x-request-id")
  request_id
}

pub fn readiness_route_returns_service_unavailable_without_database_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/ready")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.service_unavailable)

  request_id_header(response)
  |> string.starts_with("req_")
  |> should.equal(True)
}

pub fn health_route_returns_ok_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/health")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.ok)
}

pub fn unknown_route_returns_not_found_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/unknown")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.not_found)
}

pub fn health_route_supports_head_test() {
  let request =
    request.new()
    |> request.set_method(http.Head)
    |> request.set_path("/health")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.ok)
}

pub fn allowed_origin_receives_credentialed_cors_headers_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/health")
    |> request.set_header("origin", "http://localhost:1234")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  list.key_find(response.headers, "access-control-allow-origin")
  |> should.equal(Ok("http://localhost:1234"))

  list.key_find(response.headers, "access-control-allow-credentials")
  |> should.equal(Ok("true"))

  list.key_find(response.headers, "vary")
  |> should.equal(Ok("Origin"))
}

pub fn origin_port_must_match_exactly_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/health")
    |> request.set_header("origin", "http://localhost:4321")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.ok)

  list.key_find(response.headers, "access-control-allow-origin")
  |> should.equal(Error(Nil))
}

pub fn valid_preflight_returns_explicit_policy_test() {
  let request =
    request.new()
    |> request.set_method(http.Options)
    |> request.set_path("/health")
    |> request.set_header("origin", "http://localhost:1234")
    |> request.set_header("access-control-request-method", "GET")
    |> request.set_header("access-control-request-headers", "Content-Type")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.no_content)

  list.key_find(response.headers, "access-control-allow-origin")
  |> should.equal(Ok("http://localhost:1234"))

  list.key_find(response.headers, "access-control-allow-credentials")
  |> should.equal(Ok("true"))

  list.key_find(response.headers, "access-control-allow-methods")
  |> should.equal(Ok("GET, HEAD"))

  list.key_find(response.headers, "access-control-allow-headers")
  |> should.equal(Ok("Content-Type"))

  list.key_find(response.headers, "vary")
  |> should.equal(Ok(
    "Origin, Access-Control-Request-Method, Access-Control-Request-Headers",
  ))
}

pub fn preflight_rejects_unlisted_request_header_test() {
  let request =
    request.new()
    |> request.set_method(http.Options)
    |> request.set_path("/health")
    |> request.set_header("origin", "http://localhost:1234")
    |> request.set_header("access-control-request-method", "GET")
    |> request.set_header("access-control-request-headers", "Authorization")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.forbidden)

  list.key_find(response.headers, "access-control-allow-origin")
  |> should.equal(Error(Nil))
}

pub fn preflight_rejects_unlisted_method_test() {
  let request =
    request.new()
    |> request.set_method(http.Options)
    |> request.set_path("/health")
    |> request.set_header("origin", "http://localhost:1234")
    |> request.set_header("access-control-request-method", "POST")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.forbidden)
}

pub fn cross_site_unsafe_request_is_rejected_before_routing_test() {
  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_path("/health")
    |> request.set_header("origin", "https://evil.example")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.forbidden)
  case response.body {
    wisp.Text(body) ->
      body
      |> string.contains(api_error.csrf_forbidden_code)
      |> should.equal(True)
    _ -> panic as "Expected JSON text response"
  }
}

pub fn allowed_origin_unsafe_request_reaches_routing_test() {
  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_path("/health")
    |> request.set_header("origin", "http://localhost:1234")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.method_not_allowed)
  list.key_find(response.headers, "access-control-allow-origin")
  |> should.equal(Ok("http://localhost:1234"))
}

pub fn health_route_rejects_unsupported_method_test() {
  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_path("/health")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request, test_dependencies())

  response.status
  |> should.equal(status.method_not_allowed)

  list.key_find(response.headers, "allow")
  |> should.equal(Ok("GET, HEAD"))
}
