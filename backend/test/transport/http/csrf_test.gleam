import config/origins
import config/transport
import gleam/http
import gleam/http/request
import gleam/list
import gleam/string
import gleeunit/should
import transport/http/middleware/csrf
import transport/http/protocol/http_errors
import transport/transport_context
import wisp

const frontend_origin = "https://app.example.com"

pub fn safe_method_does_not_require_origin_test() {
  let assert Ok(response) =
    request(http.Get)
    |> csrf.handle(origins(), transport(), transport_context.new(), fn(_) {
      Ok(wisp.ok())
    })

  response.status
  |> should.equal(200)
}

pub fn allowed_cross_origin_write_keeps_session_cookie_test() {
  let request =
    request(http.Post)
    |> request.set_header("origin", frontend_origin)
    |> request.set_header("cookie", "roxy_session=token")

  let assert Ok(response) =
    csrf.handle(request, origins(), transport(), transport_context.new(), fn(
      protected_request,
    ) {
      protected_request
      |> request.get_cookies
      |> list.key_find("roxy_session")
      |> should.equal(Ok("token"))
      Ok(wisp.ok())
    })

  response.status
  |> should.equal(200)
}

pub fn public_backend_origin_is_allowed_test() {
  let request =
    request(http.Delete)
    |> request.set_header("origin", "https://api.example.com")

  let assert Ok(response) =
    csrf.handle(request, origins(), transport(), transport_context.new(), fn(_) {
      Ok(wisp.ok())
    })

  response.status
  |> should.equal(200)
}

pub fn allowed_referer_is_used_when_origin_is_missing_test() {
  let request =
    request(http.Patch)
    |> request.set_header("referer", frontend_origin <> "/settings?tab=profile")

  let assert Ok(response) =
    csrf.handle(request, origins(), transport(), transport_context.new(), fn(_) {
      Ok(wisp.ok())
    })

  response.status
  |> should.equal(200)
}

pub fn disallowed_origin_rejects_write_test() {
  let result =
    request(http.Post)
    |> request.set_header("origin", "https://evil.example")
    |> csrf.handle(origins(), transport(), transport_context.new(), fn(_) {
      Ok(wisp.ok())
    })

  result
  |> should.equal(Error(http_errors.CsrfForbidden))
}

pub fn malformed_origin_rejects_write_test() {
  let result =
    request(http.Post)
    |> request.set_header("origin", "not an origin")
    |> csrf.handle(origins(), transport(), transport_context.new(), fn(_) {
      Ok(wisp.ok())
    })

  result
  |> should.equal(Error(http_errors.CsrfForbidden))
}

pub fn missing_origin_strips_cookies_before_write_test() {
  let request =
    request(http.Post)
    |> request.set_header("cookie", "roxy_session=token; preference=compact")

  let assert Ok(_) =
    csrf.handle(request, origins(), transport(), transport_context.new(), fn(
      protected_request,
    ) {
      request.get_header(protected_request, "cookie")
      |> should.equal(Error(Nil))
      Ok(wisp.ok())
    })
}

pub fn origin_header_does_not_accept_paths_test() {
  let result =
    request(http.Post)
    |> request.set_header("origin", frontend_origin <> "/path")
    |> csrf.handle(origins(), transport(), transport_context.new(), fn(_) {
      Ok(wisp.ok())
    })

  result
  |> should.equal(Error(http_errors.CsrfForbidden))
}

fn request(method: http.Method) -> wisp.Request {
  request.new()
  |> request.set_method(method)
  |> request.set_path("/resource")
  |> request.set_header("host", "api.example.com")
  |> request.set_body(wisp.create_canned_connection(
    <<>>,
    "test-secret-key-base-that-is-long-enough-for-wisp",
  ))
}

fn origins() -> origins.OriginsConfig {
  origins.OriginsConfig(allowed: [string.lowercase(frontend_origin)])
}

fn transport() -> transport.TransportConfig {
  transport.TransportConfig(
    public_base_url: "https://api.example.com",
    trusted_proxy_ips: [],
    trusted_internal_ips: [],
  )
}
