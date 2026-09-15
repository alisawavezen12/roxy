import application/dependencies
import application/services/user as user_service
import gleam/json
import gleam/option
import shared/api/error as api_error
import shared/http_status as status
import shared/user
import transport/http/protocol/api_errors
import transport/transport_context
import wisp

pub fn handle(
  id: String,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case
    user_service.find(
      dependencies.postgres,
      id,
      dependencies.config.postgres.query_timeout,
    )
  {
    Ok(option.Some(user)) -> response(user)
    Ok(option.None) ->
      api_errors.response(
        status.not_found,
        api_error.not_found_code,
        "User not found",
        context,
      )
    Error(_) ->
      api_errors.response(
        status.internal_server_error,
        api_error.internal_error_code,
        api_error.internal_error_message,
        context,
      )
  }
}

pub fn response(value: user.User) -> wisp.Response {
  json.object([#("user", user.encode(value))])
  |> json.to_string
  |> wisp.json_response(status.ok)
}
