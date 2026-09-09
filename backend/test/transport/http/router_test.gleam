import application/dependencies
import config/app
import config/environment
import config/origins
import db/config as postgres_config_module
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import pog
import transport/http/router
import wisp

pub fn main() {
  gleeunit.main()
}

fn test_dependencies() -> dependencies.Dependencies {
  let config =
    app.AppConfig(
      host: "0.0.0.0",
      port: 8080,
      environment: environment.Development,
      secret_key_base: "test-secret-key-base-that-is-long-enough-for-wisp",
      origins: origins.OriginsConfig(allowed: ["http://localhost:1234"]),
      postgres: postgres_config(),
    )
  dependencies.new(config, pog.named_connection(process.new_name("test_pool")))
}

fn postgres_config() -> postgres_config_module.PostgresConfig {
  postgres_config_module.PostgresConfig(
    url: "postgres://test",
    pool_size: 1,
    query_timeout: 1000,
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
  |> should.equal(503)

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
  |> should.equal(200)
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
  |> should.equal(404)
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
  |> should.equal(200)
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
  |> should.equal(200)

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
  |> should.equal(204)

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
  |> should.equal(403)

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
  |> should.equal(403)
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
  |> should.equal(405)

  list.key_find(response.headers, "allow")
  |> should.equal(Ok("GET, HEAD"))
}
