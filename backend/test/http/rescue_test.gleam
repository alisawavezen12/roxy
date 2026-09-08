import gleam/http/request
import gleam/list
import gleam/string
import gleeunit/should
import http/middleware/error_handler
import http/request_context
import wisp

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
