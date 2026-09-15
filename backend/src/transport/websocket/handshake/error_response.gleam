import application/access
import gleam/bytes_tree
import gleam/http
import gleam/http/response
import gleam/list
import gleam/option
import gleam/string
import mist
import shared/api/error as api_error
import shared/http_status as status
import transport/transport_context
import transport/websocket/handshake/validation

pub fn response(
  error: validation.HandshakeError,
  context: transport_context.TransportContext,
) -> response.Response(mist.ResponseData) {
  let #(status, code, message, allow) = case error {
    validation.MethodNotAllowed(methods) -> #(
      status.method_not_allowed,
      api_error.method_not_allowed_code,
      api_error.method_not_allowed_message,
      option.Some(methods_header(methods)),
    )
    validation.OriginNotAllowed -> #(
      status.forbidden,
      api_error.forbidden_code,
      api_error.forbidden_message,
      option.None,
    )
    validation.InvalidHandshake -> #(
      status.bad_request,
      api_error.invalid_handshake_code,
      api_error.invalid_handshake_message,
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
    access.Unauthenticated -> #(
      status.unauthorized,
      api_error.unauthorized_code,
      api_error.unauthorized_message,
    )
    access.Forbidden -> #(
      status.forbidden,
      api_error.forbidden_code,
      api_error.forbidden_message,
    )
  }
}
