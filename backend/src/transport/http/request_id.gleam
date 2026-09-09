import transport/transport_context.{type TransportContext}
import wisp

pub fn add_request_id(
  response: wisp.Response,
  context: TransportContext,
) -> wisp.Response {
  wisp.set_header(response, "x-request-id", context.request_id)
}
