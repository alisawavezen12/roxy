import application/dependencies
import transport/http/protocol/responses
import transport/http/protocol/status
import transport/transport_context
import wisp

pub fn handle(
  app_dependencies: dependencies.Dependencies,
  _context: transport_context.TransportContext,
) -> wisp.Response {
  case dependencies.postgres_ready(app_dependencies) {
    True -> responses.text(status.ok, "OK")
    False -> responses.text(status.service_unavailable, "Not Ready")
  }
}
