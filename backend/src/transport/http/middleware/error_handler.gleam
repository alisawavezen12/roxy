import application/access
import gleam/http
import gleam/list
import gleam/option
import gleam/string
import transport/http/protocol/api_errors
import transport/http/protocol/http_errors
import transport/http/protocol/status
import transport/http/request_id
import transport/protocol/messages
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
        messages.internal_error_code,
        messages.internal_error_message,
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
      api_errors.response(
        status.not_found,
        messages.not_found_code,
        messages.not_found_message,
        context,
      )
    http_errors.MethodNotAllowed(methods) ->
      api_errors.response_with_allow(
        status.method_not_allowed,
        messages.method_not_allowed_code,
        messages.method_not_allowed_message,
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
        messages.unsupported_media_type_code,
        messages.unsupported_media_type_message,
        context,
      )
    http_errors.InvalidBody ->
      api_errors.response(
        status.bad_request,
        messages.invalid_body_code,
        messages.invalid_body_message,
        context,
      )
    http_errors.PayloadTooLarge -> api_errors.payload_too_large(context)
    http_errors.TooManyRequests ->
      api_errors.response(
        status.too_many_requests,
        messages.rate_limited_code,
        messages.rate_limited_message,
        context,
      )
    http_errors.CsrfForbidden ->
      api_errors.response(
        status.forbidden,
        messages.csrf_forbidden_code,
        messages.csrf_forbidden_message,
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
        messages.unauthorized_code,
        messages.unauthorized_message,
        context,
      )
    access.Forbidden ->
      api_errors.response(
        status.forbidden,
        messages.forbidden_code,
        messages.forbidden_message,
        context,
      )
  }
}
