import gleam/bytes_tree
import gleam/http/response
import mist
import shared/api/error as api_error
import transport/http/protocol/status
import transport/protocol/messages
import transport/transport_context

pub fn too_many_requests(
  context: transport_context.TransportContext,
) -> response.Response(mist.ResponseData) {
  let request_id = transport_context.request_id(context)
  let body =
    "{\"error\":{\"code\":\""
    <> api_error.rate_limited_code
    <> "\",\"message\":\""
    <> api_error.rate_limited_message
    <> "\",\"request_id\":\""
    <> request_id
    <> "\"}}"
  response.new(status.too_many_requests)
  |> response.set_header("content-type", "application/json; charset=utf-8")
  |> response.set_header("x-request-id", request_id)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

pub fn service_unavailable() -> response.Response(mist.ResponseData) {
  response.new(status.service_unavailable)
  |> response.set_body(
    mist.Bytes(bytes_tree.from_string(messages.service_unavailable)),
  )
}

pub fn insecure_transport() -> response.Response(mist.ResponseData) {
  response.new(status.bad_request)
  |> response.set_body(
    mist.Bytes(bytes_tree.from_string(messages.insecure_transport)),
  )
}
