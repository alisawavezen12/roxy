import application/dependencies
import shared/http_status as status
import transport/http/protocol/responses
import transport/protocol/messages
import transport/transport_context
import wisp

pub fn handle(
  app_dependencies: dependencies.Dependencies,
  _context: transport_context.TransportContext,
) -> wisp.Response {
  case dependencies.postgres_ready(app_dependencies) {
    True -> responses.text(status.ok, messages.ok)
    False -> responses.text(status.service_unavailable, messages.not_ready)
  }
}
