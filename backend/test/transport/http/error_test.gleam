import application/access
import gleam/http
import gleam/list
import gleam/string
import gleeunit/should
import transport/http/middleware/error_handler
import transport/http/protocol/http_errors
import transport/transport_context
import wisp

pub fn route_not_found_maps_to_http_404_test() {
  let response =
    error_handler.response(http_errors.NotFound, transport_context.new())

  response.status
  |> should.equal(404)

  response
  |> body
  |> string.contains("not_found")
  |> should.equal(True)
}

pub fn method_not_allowed_maps_to_http_405_with_allow_test() {
  let response =
    error_handler.response(
      http_errors.MethodNotAllowed([http.Get, http.Head]),
      transport_context.new(),
    )

  response.status
  |> should.equal(405)

  list.key_find(response.headers, "allow")
  |> should.equal(Ok("GET, HEAD"))

  response
  |> body
  |> string.contains("method_not_allowed")
  |> should.equal(True)
}

pub fn unsupported_media_type_maps_to_http_415_test() {
  let response =
    error_handler.response(
      http_errors.UnsupportedMediaType,
      transport_context.new(),
    )

  response.status
  |> should.equal(415)

  response
  |> body
  |> string.contains("unsupported_media_type")
  |> should.equal(True)
}

pub fn payload_too_large_maps_to_http_413_test() {
  let response =
    error_handler.response(http_errors.PayloadTooLarge, transport_context.new())

  response.status
  |> should.equal(413)

  response
  |> body
  |> string.contains("payload_too_large")
  |> should.equal(True)
}

pub fn unauthenticated_access_maps_to_http_401_test() {
  let response =
    error_handler.response(
      http_errors.Access(access.Unauthenticated),
      transport_context.new(),
    )

  response.status
  |> should.equal(401)

  response
  |> body
  |> string.contains("unauthorized")
  |> should.equal(True)
}

pub fn forbidden_access_maps_to_http_403_test() {
  let response =
    error_handler.response(
      http_errors.Access(access.Forbidden),
      transport_context.new(),
    )

  response.status
  |> should.equal(403)

  response
  |> body
  |> string.contains("forbidden")
  |> should.equal(True)
}

pub fn mapped_http_errors_keep_request_id_test() {
  let context = transport_context.new()
  let response = error_handler.response(http_errors.NotFound, context)

  list.key_find(response.headers, "x-request-id")
  |> should.equal(Ok(transport_context.request_id(context)))
}

fn body(response: wisp.Response) -> String {
  case response.body {
    wisp.Text(value) -> value
    _ -> panic as "Expected JSON text response"
  }
}
