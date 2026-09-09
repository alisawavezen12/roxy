import application/access
import gleam/bytes_tree
import gleam/http
import gleam/http/response
import gleam/list
import gleam/option
import gleam/string
import mist
import transport/transport_context
import transport/websocket/handshake/validation

pub fn response(
  error: validation.HandshakeError,
  context: transport_context.TransportContext,
) -> response.Response(mist.ResponseData) {
  let #(status, code, message, allow) = case error {
    validation.MethodNotAllowed(methods) -> #(
      405,
      "method_not_allowed",
      "Method not allowed",
      option.Some(methods_header(methods)),
    )
    validation.OriginNotAllowed -> #(403, "forbidden", "Forbidden", option.None)
    validation.InvalidHandshake -> #(
      400,
      "invalid_input",
      "Invalid WebSocket handshake",
      option.None,
    )
    validation.Access(error) -> {
      let #(status, code, message) = access_error_details(error)
      #(status, code, message, option.None)
    }
  }
  let body =
    "{\"error\":{\"code\":\""
    <> code
    <> "\",\"message\":\""
    <> message
    <> "\",\"request_id\":\""
    <> transport_context.request_id(context)
    <> "\"}}"

  let response =
    response.new(status)
    |> response.set_header("content-type", "application/json; charset=utf-8")
    |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
  case allow {
    option.Some(value) -> response.set_header(response, "allow", value)
    option.None -> response
  }
}

fn methods_header(methods: List(http.Method)) -> String {
  methods
  |> list.map(http.method_to_string)
  |> string.join(", ")
}

fn access_error_details(error: access.AccessError) -> #(Int, String, String) {
  case error {
    access.Unauthenticated -> #(401, "unauthorized", "Unauthorized")
    access.Forbidden -> #(403, "forbidden", "Forbidden")
  }
}
