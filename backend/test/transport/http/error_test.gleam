import application/access
import gleam/http
import gleam/list
import gleam/string
import gleeunit/should

import shared/api/error as api_error
import shared/http_status as status
import transport/http/middleware/error_handler
import transport/http/protocol/http_errors
import transport/transport_context
import wisp

pub fn route_not_found_maps_to_http_404_test() {
  let response =
    error_handler.response(http_errors.NotFound, transport_context.new())

  response.status
  |> should.equal(status.not_found)

  response
  |> body
  |> string.contains(api_error.not_found_code)
  |> should.equal(True)
}

pub fn method_not_allowed_maps_to_http_405_with_allow_test() {
  let response =
    error_handler.response(
      http_errors.MethodNotAllowed([http.Get, http.Head]),
      transport_context.new(),
    )

  response.status
  |> should.equal(status.method_not_allowed)

  list.key_find(response.headers, "allow")
  |> should.equal(Ok("GET, HEAD"))

  response
  |> body
  |> string.contains(api_error.method_not_allowed_code)
  |> should.equal(True)
}

pub fn unsupported_media_type_maps_to_http_415_test() {
  let response =
    error_handler.response(
      http_errors.UnsupportedMediaType,
      transport_context.new(),
    )

  response.status
  |> should.equal(status.unsupported_media_type)

  response
  |> body
  |> string.contains(api_error.unsupported_media_type_code)
  |> should.equal(True)
}

pub fn payload_too_large_maps_to_http_413_test() {
  let response =
    error_handler.response(http_errors.PayloadTooLarge, transport_context.new())

  response.status
  |> should.equal(status.payload_too_large)

  response
  |> body
  |> string.contains(api_error.payload_too_large_code)
  |> should.equal(True)
}

pub fn unauthenticated_access_maps_to_http_401_test() {
  let response =
    error_handler.response(
      http_errors.Access(access.Unauthenticated),
      transport_context.new(),
    )

  response.status
  |> should.equal(status.unauthorized)

  response
  |> body
  |> string.contains(api_error.unauthorized_code)
  |> should.equal(True)
}

pub fn forbidden_access_maps_to_http_403_test() {
  let response =
    error_handler.response(
      http_errors.Access(access.Forbidden),
      transport_context.new(),
    )

  response.status
  |> should.equal(status.forbidden)

  response
  |> body
  |> string.contains(api_error.forbidden_code)
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
