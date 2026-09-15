import application/dependencies
import shared/http_status as status
import transport/http/protocol/responses
import transport/protocol/messages
import transport/transport_context
import wisp

pub fn handle(
  _dependencies: dependencies.Dependencies,
  _context: transport_context.TransportContext,
) -> wisp.Response {
  responses.text(status.ok, messages.ok)
}
