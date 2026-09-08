import gleam/http
import gleam/http/request
import gleam/list
import gleam/string
import gleeunit/should
import http/middleware/logging as request_logging
import http/protocol/api_errors
import http/protocol/limits
import http/protocol/status
import http/request_context
import wisp

pub fn request_context_generates_server_id_test() {
  let first = request_context.new()
  let second = request_context.new()

  let first_id = request_context.request_id(first)
  let second_id = request_context.request_id(second)

  let assert "req_" <> _ = first_id
  let assert "req_" <> _ = second_id
  let assert False = first_id == second_id
}

pub fn request_id_is_added_to_response_test() {
  let context = request_context.new()
  let response =
    wisp.ok()
    |> request_context.add_request_id(context)

  list.key_find(response.headers, "x-request-id")
  |> should.equal(Ok(request_context.request_id(context)))
}

pub fn api_errors_are_json_and_keep_request_id_test() {
  let context = request_context.new()
  let response =
    api_errors.response(
      status.unsupported_media_type,
      "unsupported_media_type",
      "Unsupported media type",
      context,
    )

  response.status
  |> should.equal(415)

  list.key_find(response.headers, "content-type")
  |> should.equal(Ok("application/json; charset=utf-8"))

  list.key_find(response.headers, "x-request-id")
  |> should.equal(Ok(request_context.request_id(context)))

  case response.body {
    wisp.Text(body) -> {
      body
      |> string.contains("unsupported_media_type")
      |> should.equal(True)

      body
      |> string.contains(request_context.request_id(context))
      |> should.equal(True)
    }
    _ -> panic as "Expected JSON text response"
  }
}

pub fn http_limits_are_fixed_protocol_policy_test() {
  limits.max_body_size
  |> should.equal(1_048_576)

  limits.max_files_size
  |> should.equal(33_554_432)
}

pub fn logging_wrapper_preserves_response_test() {
  let context = request_context.new()
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/test")
    |> request.set_body(wisp.create_canned_connection(<<>>, "test-secret"))

  let response =
    request_logging.handle(request, context, fn() {
      wisp.response(status.not_found)
    })

  response.status
  |> should.equal(status.not_found)
}
