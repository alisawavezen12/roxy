import config/cors
import gleam/http
import gleam/http/request
import gleam/list
import gleam/string
import gleeunit/should
import http/middleware/cors as cors_middleware
import http/middleware/error_handler
import http/request_context
import wisp

pub fn cors_headers_are_added_to_safe_crash_response_test() {
  let context = request_context.new()
  let request =
    request.new()
    |> request.set_path("/test/crash")
    |> request.set_header("origin", "http://localhost:1234")
    |> request.set_body(wisp.create_canned_connection(<<>>, "test-secret"))
  let config =
    cors.CorsConfig(
      allowed_origins: ["http://localhost:1234"],
      allowed_methods: [http.Get, http.Head],
      allowed_headers: ["Content-Type"],
    )

  let response =
    cors_middleware.handle(request, config, context, fn() {
      error_handler.handle(request, context, fn() {
        panic as "secret stack trace must stay server-side"
      })
    })

  response.status
  |> should.equal(500)

  list.key_find(response.headers, "access-control-allow-origin")
  |> should.equal(Ok("http://localhost:1234"))
}

pub fn crashing_pipeline_returns_safe_json_500_test() {
  let context = request_context.new()
  let request =
    request.new()
    |> request.set_path("/test/crash")
    |> request.set_body(wisp.create_canned_connection(<<>>, "test-secret"))

  let response =
    error_handler.handle(request, context, fn() {
      panic as "secret stack trace must stay server-side"
    })

  response.status
  |> should.equal(500)

  list.key_find(response.headers, "x-request-id")
  |> should.equal(Ok(request_context.request_id(context)))

  case response.body {
    wisp.Text(body) -> {
      body
      |> string.contains("internal")
      |> should.equal(True)

      body
      |> string.contains("secret stack trace")
      |> should.equal(False)
    }
    _ -> panic as "Expected JSON text response"
  }
}
