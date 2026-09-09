import application/dependencies
import transport/http/protocol/responses
import transport/http/protocol/status
import transport/transport_context
import wisp

pub fn handle(
  _dependencies: dependencies.Dependencies,
  _context: transport_context.TransportContext,
) -> wisp.Response {
  responses.text(status.ok, "OK")
}
