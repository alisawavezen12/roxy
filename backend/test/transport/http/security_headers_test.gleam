import application/dependencies
import config/app
import config/environment
import config/origins
import config/session
import config/transport
import db/config as db_config
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleeunit/should
import observability/metrics
import pog
import ratelimit/limiter
import transport/http/router
import wisp

pub fn development_has_base_security_headers_without_hsts_test() {
  let response = router.handle(request("/health"), dependencies(False))

  list.key_find(response.headers, "x-content-type-options")
  |> should.equal(Ok("nosniff"))

  list.key_find(response.headers, "referrer-policy")
  |> should.equal(Ok("no-referrer"))

  list.key_find(response.headers, "strict-transport-security")
  |> should.equal(Error(Nil))
}

pub fn production_https_has_hsts_test() {
  let response = router.handle(request("/health"), dependencies(True))

  list.key_find(response.headers, "strict-transport-security")
  |> should.equal(Ok("max-age=31536000"))
}

fn request(path: String) -> wisp.Request {
  request.new()
  |> request.set_method(http.Get)
  |> request.set_path(path)
  |> request.set_body(wisp.create_canned_connection(
    <<>>,
    "test-secret-key-base-that-is-long-enough-for-wisp",
  ))
}

fn dependencies(https: Bool) -> dependencies.Dependencies {
  let base_url = case https {
    True -> "https://example.com"
    False -> "http://localhost:8080"
  }
  let config =
    app.AppConfig(
      host: "127.0.0.1",
      port: 8080,
      environment: case https {
        True -> environment.Production
        False -> environment.Development
      },
      secret_key_base: "test-secret-key-base-that-is-long-enough-for-wisp",
      origins: origins.OriginsConfig(allowed: ["http://localhost:1234"]),
      session: session.SessionConfig(ttl_seconds: 86_400, cookie_secure: !https),
      transport: transport.TransportConfig(
        public_base_url: base_url,
        trusted_proxy_ips: [],
        trusted_internal_ips: [],
      ),
      postgres: db_config.PostgresConfig(
        url: "postgres://test",
        pool_size: 1,
        query_timeout: 1000,
      ),
    )
  dependencies.new(
    config,
    pog.named_connection(process.new_name("security_headers_test_pool")),
    limiter_for_test(),
    metrics_for_test(),
  )
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
