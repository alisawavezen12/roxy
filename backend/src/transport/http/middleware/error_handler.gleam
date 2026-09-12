import application/access
import gleam/http
import gleam/list
import gleam/option
import gleam/string
import transport/http/protocol/api_errors
import transport/http/protocol/http_errors
import transport/http/protocol/status
import transport/http/request_id
import transport/transport_context
import wisp

pub fn handle(
  _request: wisp.Request,
  context: transport_context.TransportContext,
  next: fn() -> Result(wisp.Response, http_errors.HttpError),
) -> wisp.Response {
  let response =
    wisp.rescue_crashes(fn() {
      case next() {
        Ok(response) -> response
        Error(error) -> response(error, context)
      }
    })
  case response.status == status.internal_server_error {
    True ->
      api_errors.response(
        status.internal_server_error,
        "internal",
        "Internal server error",
        context,
      )
    _ -> request_id.add_request_id(response, context)
  }
}

pub fn response(
  error: http_errors.HttpError,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case error {
    http_errors.NotFound ->
      api_errors.response(status.not_found, "not_found", "Not found", context)
    http_errors.MethodNotAllowed(methods) ->
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
    http_errors.UnsupportedMediaType ->
      api_errors.response(
        status.unsupported_media_type,
        "unsupported_media_type",
        "Unsupported media type",
        context,
      )
    http_errors.InvalidBody ->
      api_errors.response(
        status.bad_request,
        "invalid_body",
        "Invalid request body",
        context,
      )
    http_errors.PayloadTooLarge -> api_errors.payload_too_large(context)
    http_errors.TooManyRequests ->
      api_errors.response(
        status.too_many_requests,
        "rate_limited",
        "Too many requests",
        context,
      )
    http_errors.CsrfForbidden ->
      api_errors.response(
        status.forbidden,
        "csrf_forbidden",
        "Request origin is not allowed",
        context,
      )
    http_errors.Access(error) -> access_response(error, context)
  }
}

fn access_response(
  error: access.AccessError,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case error {
    access.Unauthenticated ->
      api_errors.response(
        status.unauthorized,
        "unauthorized",
        "Unauthorized",
        context,
      )
    access.Forbidden ->
      api_errors.response(status.forbidden, "forbidden", "Forbidden", context)
  }
}
