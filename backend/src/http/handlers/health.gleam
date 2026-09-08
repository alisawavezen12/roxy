import dependencies
import http/protocol/responses
import http/protocol/status
import http/request_context
import wisp

pub fn handle(
  _dependencies: dependencies.Dependencies,
  _context: request_context.RequestContext,
) -> wisp.Response {
  responses.text(status.ok, "OK")
}
