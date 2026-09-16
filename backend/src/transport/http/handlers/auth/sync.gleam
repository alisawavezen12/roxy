import application/dependencies
import application/services/auth/authentication
import application/services/auth/dobrunia

import gleam/option
import shared/api/error as api_error
import shared/http_status as status
import transport/http/handlers/user as user_handler
import transport/http/protocol/api_errors
import transport/session
import transport/transport_context
import wisp

pub fn handle(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case transport_context.principal(context), session.token(http_request) {
    option.Some(principal), option.Some(session_token) ->
      case
        authentication.sync_profile(
          dependencies.postgres,
          dependencies.config.auth,
          session_token,
          principal.user_id,
          dependencies.config.postgres.query_timeout,
        )
      {
        Ok(profile) -> user_handler.response(profile)
        Error(authentication.Auth(dobrunia.Rejected(401))) ->
          unauthorized(context)
        Error(authentication.Auth(_)) -> provider_error(context)
        Error(authentication.InvalidStoredToken) -> unauthorized(context)
        Error(authentication.Database(_)) -> database_error(context)
      }
    _, _ -> unauthorized(context)
  }
}

fn unauthorized(context: transport_context.TransportContext) -> wisp.Response {
  api_errors.response(
    status.unauthorized,
    api_error.unauthorized_code,
    api_error.unauthorized_message,
    context,
  )
}

fn provider_error(
  context: transport_context.TransportContext,
) -> wisp.Response {
  api_errors.response(
    status.service_unavailable,
    "identity_provider_unavailable",
    "Identity provider request failed",
    context,
  )
}

fn database_error(
  context: transport_context.TransportContext,
) -> wisp.Response {
  api_errors.response(
    status.internal_server_error,
    api_error.internal_error_code,
    api_error.internal_error_message,
    context,
  )
}
