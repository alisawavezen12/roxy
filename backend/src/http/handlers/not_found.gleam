import gleam/http/response
import http/response as http_response
import http/status
import mist

pub fn handle() -> response.Response(mist.ResponseData) {
  http_response.text(status.not_found, "Not found")
}
