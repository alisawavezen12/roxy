import gleam/json
import gleam/option
import shared/api/error as api_error
import transport/http/protocol/status
import transport/transport_context
import wisp

pub fn response(
  status_code: Int,
  code: String,
  message: String,
  context: transport_context.TransportContext,
) -> wisp.Response {
  response_with_allow(status_code, code, message, context, option.None)
}

pub fn response_with_allow(
  status_code: Int,
  code: String,
  message: String,
  context: transport_context.TransportContext,
  allow: option.Option(String),
) -> wisp.Response {
  let body =
    json.object([
      #(
        "error",
        json.object([
          #("code", json.string(code)),
          #("message", json.string(message)),
          #("request_id", json.string(transport_context.request_id(context))),
        ]),
      ),
    ])
    |> json.to_string

  let response =
    wisp.response(status_code)
    |> wisp.set_header("content-type", "application/json; charset=utf-8")
    |> wisp.set_header("x-request-id", transport_context.request_id(context))
  case allow {
    option.Some(value) -> wisp.set_header(response, "allow", value)
    option.None -> response
  }
  |> wisp.string_body(body)
}

pub fn payload_too_large(
  context: transport_context.TransportContext,
) -> wisp.Response {
  response(
    status.payload_too_large,
    api_error.payload_too_large_code,
    api_error.payload_too_large_message,
    context,
  )
}
