import gleam/http
import gleam/http/request

import gleam/string
import gleeunit/should
import shared/api/error as api_error
import shared/http_status as status
import transport/http/request_body
import transport/transport_context
import wisp

pub fn malformed_json_maps_to_400_test() {
  let response = parse_json(<<"{":utf8>>)

  response.status
  |> should.equal(status.bad_request)

  body(response)
  |> string.contains(api_error.invalid_body_code)
  |> should.equal(True)
}

pub fn unsupported_json_content_type_maps_to_415_test() {
  let response = parse_json_with_content_type("text/plain", <<"{}":utf8>>)

  response.status
  |> should.equal(status.unsupported_media_type)

  body(response)
  |> string.contains(api_error.unsupported_media_type_code)
  |> should.equal(True)
}

pub fn valid_json_is_passed_as_transport_body_test() {
  let response = parse_json(<<"{\"name\":\"roxy\"}":utf8>>)

  response.status
  |> should.equal(status.ok)
}

pub fn multipart_without_boundary_maps_to_400_test() {
  let response =
    parse_body(
      request.new()
        |> request.set_method(http.Post)
        |> request.set_header("content-type", "multipart/form-data")
        |> request.set_body(wisp.create_canned_connection(
          <<>>,
          "test-secret-key-base-that-is-long-enough-for-wisp",
        )),
      request_body.Multipart,
    )

  response.status
  |> should.equal(status.bad_request)
}

fn parse_json(body_bits: BitArray) -> wisp.Response {
  parse_json_with_content_type("application/json", body_bits)
}

fn parse_json_with_content_type(
  content_type: String,
  body_bits: BitArray,
) -> wisp.Response {
  parse_body(
    request.new()
      |> request.set_method(http.Post)
      |> request.set_header("content-type", content_type)
      |> request.set_body(wisp.create_canned_connection(
        body_bits,
        "test-secret-key-base-that-is-long-enough-for-wisp",
      )),
    request_body.Json,
  )
}

fn parse_body(
  request: wisp.Request,
  contract: request_body.Contract,
) -> wisp.Response {
  request_body.parse(request, contract, transport_context.new(), fn(body) {
    case body {
      request_body.JsonBody(value) ->
        wisp.ok()
        |> wisp.string_body(value)
      request_body.MultipartBody(_) -> wisp.ok()
      request_body.EmptyBody -> wisp.ok()
    }
  })
}

fn body(response: wisp.Response) -> String {
  case response.body {
    wisp.Text(value) -> value
    _ -> panic as "Expected JSON text response"
  }
}
