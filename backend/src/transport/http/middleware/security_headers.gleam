import config/transport
import gleam/http/response
import mist
import transport/transport_context
import wisp

pub fn handle(
  response: wisp.Response,
  config: transport.TransportConfig,
) -> wisp.Response {
  let response =
    response
    |> wisp.set_header("x-content-type-options", "nosniff")
    |> wisp.set_header("referrer-policy", "no-referrer")
  case transport.public_https(config) {
    True ->
      wisp.set_header(response, "strict-transport-security", "max-age=31536000")
    False -> response
  }
}

pub fn handle_mist(
  value: response.Response(mist.ResponseData),
  config: transport.TransportConfig,
  context: transport_context.TransportContext,
) -> response.Response(mist.ResponseData) {
  let value =
    value
    |> response.set_header("x-content-type-options", "nosniff")
    |> response.set_header("referrer-policy", "no-referrer")
    |> response.set_header(
      "x-request-id",
      transport_context.request_id(context),
    )
  case transport.public_https(config) {
    True ->
      response.set_header(
        value,
        "strict-transport-security",
        "max-age=31536000",
      )
    False -> value
  }
}
