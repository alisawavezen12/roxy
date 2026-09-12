import application/access
import config/origins
import gleam/bit_array
import gleam/bytes_tree
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}

import gleam/result
import gleam/string
import gleeunit/should
import mist
import shared/api/error as api_error
import transport/http/protocol/status
import transport/transport_context
import transport/websocket/handshake/error_response
import transport/websocket/handshake/validation

pub fn method_not_allowed_maps_to_handshake_405_test() {
  let response =
    error_response.response(
      validation.MethodNotAllowed([http.Get]),
      transport_context.new(),
    )

  response.status
  |> should.equal(status.method_not_allowed)

  response
  |> body
  |> string.contains(api_error.method_not_allowed_code)
  |> should.equal(True)
}

pub fn origin_not_allowed_maps_to_handshake_403_test() {
  let response =
    error_response.response(
      validation.OriginNotAllowed,
      transport_context.new(),
    )

  response.status
  |> should.equal(status.forbidden)

  response
  |> body
  |> string.contains(api_error.forbidden_code)
  |> should.equal(True)
}

pub fn invalid_handshake_maps_to_handshake_400_test() {
  let response =
    error_response.response(
      validation.InvalidHandshake,
      transport_context.new(),
    )

  response.status
  |> should.equal(status.bad_request)

  response
  |> body
  |> string.contains(api_error.invalid_handshake_code)
  |> should.equal(True)
}

pub fn unauthenticated_access_maps_to_handshake_401_test() {
  let response =
    error_response.response(
      validation.Access(access.Unauthenticated),
      transport_context.new(),
    )

  response.status
  |> should.equal(status.unauthorized)

  response
  |> body
  |> string.contains(api_error.unauthorized_code)
  |> should.equal(True)
}

pub fn forbidden_access_maps_to_handshake_403_test() {
  let response =
    error_response.response(
      validation.Access(access.Forbidden),
      transport_context.new(),
    )

  response.status
  |> should.equal(status.forbidden)

  response
  |> body
  |> string.contains(api_error.forbidden_code)
  |> should.equal(True)
}

pub fn invalid_method_is_rejected_by_validation_test() {
  let request = request.new() |> request.set_method(http.Post)
  let origins = origins_config()

  validation.validate(request, [http.Get], origins)
  |> should.equal(Error(validation.MethodNotAllowed([http.Get])))
}

pub fn malformed_upgrade_is_rejected_by_validation_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_header("origin", "http://localhost:1234")
  let origins = origins_config()

  validation.validate(request, [http.Get], origins)
  |> should.equal(Error(validation.InvalidHandshake))
}

pub fn missing_origin_is_rejected_by_validation_test() {
  let request = request.new() |> request.set_method(http.Get)
  let origins = origins_config()

  validation.validate(request, [http.Get], origins)
  |> should.equal(Error(validation.OriginNotAllowed))
}

pub fn handshake_errors_keep_request_id_test() {
  let context = transport_context.new()
  let response = error_response.response(validation.InvalidHandshake, context)

  response
  |> body
  |> string.contains(transport_context.request_id(context))
  |> should.equal(True)
}

fn origins_config() -> origins.OriginsConfig {
  origins.OriginsConfig(allowed: ["http://localhost:1234"])
}

fn body(response: Response(mist.ResponseData)) -> String {
  case response.body {
    mist.Bytes(bytes) ->
      bytes
      |> bytes_tree.to_bit_array
      |> bit_array.to_string
      |> result.unwrap(or: "")
    _ -> panic as "Expected JSON response body"
  }
}
