import dependencies
import http/protocol/responses
import http/protocol/status
import wisp

pub fn handle(_dependencies: dependencies.Dependencies) -> wisp.Response {
  responses.text(status.ok, "OK")
}
