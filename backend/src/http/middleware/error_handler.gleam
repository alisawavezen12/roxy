import gleam/http
import gleam/list
import gleam/option
import gleam/string
import http/protocol/api_errors
import http/protocol/route_errors
import http/protocol/status
import http/request_context
import wisp

pub fn handle(
  _request: wisp.Request,
  context: request_context.RequestContext,
  next: fn() -> Result(wisp.Response, route_errors.Error),
) -> wisp.Response {
  wisp.rescue_crashes(fn() {
    case next() {
      Ok(response) -> response
      Error(error) -> response(error, context)
    }
  })
}

pub fn response(
  error: route_errors.Error,
  context: request_context.RequestContext,
) -> wisp.Response {
  case error {
    route_errors.NotFound ->
      api_errors.response(status.not_found, "not_found", "Not found", context)
    route_errors.MethodNotAllowed(methods) ->
      api_errors.response_with_allow(
        status.method_not_allowed,
        "method_not_allowed",
        "Method not allowed",
        context,
        option.Some(
          methods
          |> list.map(http.method_to_string)
          |> string.join(", "),
        ),
      )
    route_errors.Unauthorized ->
      api_errors.response(
        status.unauthorized,
        "unauthorized",
        "Unauthorized",
        context,
      )
    route_errors.Forbidden ->
      api_errors.response(status.forbidden, "forbidden", "Forbidden", context)
    route_errors.UnsupportedMediaType ->
      api_errors.response(
        status.unsupported_media_type,
        "unsupported_media_type",
        "Unsupported media type",
        context,
      )
    route_errors.PayloadTooLarge -> api_errors.payload_too_large(context)
    route_errors.Internal ->
      api_errors.response(
        status.internal_server_error,
        "internal",
        "Internal server error",
        context,
      )
  }
}
