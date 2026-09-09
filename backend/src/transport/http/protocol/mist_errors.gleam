import gleam/bytes_tree
import gleam/http/response
import mist
import transport/transport_context

pub fn too_many_requests(
  context: transport_context.TransportContext,
) -> response.Response(mist.ResponseData) {
  let request_id = transport_context.request_id(context)
  let body =
    "{\"error\":{\"code\":\"rate_limited\",\"message\":\"Too many requests\",\"request_id\":\""
    <> request_id
    <> "\"}}"

  response.new(429)
  |> response.set_header("content-type", "application/json; charset=utf-8")
  |> response.set_header("x-request-id", request_id)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

pub fn service_unavailable() -> response.Response(mist.ResponseData) {
  response.new(503)
  |> response.set_body(
    mist.Bytes(bytes_tree.from_string("Service Unavailable")),
  )
}
