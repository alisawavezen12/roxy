import errors
import http/protocol/responses
import http/protocol/status
import wisp

pub fn handle(
  _request: wisp.Request,
  next: fn() -> Result(wisp.Response, errors.Error),
) -> wisp.Response {
  wisp.rescue_crashes(fn() {
    case next() {
      Ok(response) -> response
      Error(error) -> response(error)
    }
  })
}

pub fn response(error: errors.Error) -> wisp.Response {
  case error {
    errors.NotFound -> responses.text(status.not_found, "Not found")
    errors.MethodNotAllowed(methods) -> responses.method_not_allowed(methods)
    errors.Unauthorized -> responses.text(status.unauthorized, "Unauthorized")
    errors.Forbidden -> responses.text(status.forbidden, "Forbidden")
    errors.Internal ->
      responses.text(status.internal_server_error, "Internal server error")
  }
}
