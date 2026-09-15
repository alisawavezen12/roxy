import application/dependencies
import application/services/user
import gleam/option
import shared/api/error as api_error
import shared/http_status as status
import transport/http/handlers/user as user_handler
import transport/http/protocol/api_errors
import transport/transport_context
import wisp

pub fn handle(
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case transport_context.principal(context) {
    option.None -> unauthorized(context)
    option.Some(principal) ->
      case
        user.find(
          dependencies.postgres,
          principal.user_id,
          dependencies.config.postgres.query_timeout,
        )
      {
        Ok(option.Some(user)) -> user_handler.response(user)
        Ok(option.None) -> unauthorized(context)
        Error(_) ->
          api_errors.response(
            status.internal_server_error,
            api_error.internal_error_code,
            api_error.internal_error_message,
            context,
          )
      }
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
