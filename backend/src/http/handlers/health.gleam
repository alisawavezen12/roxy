import http/protocol/responses
import http/protocol/status
import wisp

pub fn handle() -> wisp.Response {
  responses.text(status.ok, "OK")
}
