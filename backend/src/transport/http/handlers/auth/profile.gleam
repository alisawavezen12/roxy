import application/dependencies
import application/services/profile
import application/services/user
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import shared/api/error as api_error
import shared/http_status as status
import transport/http/handlers/user as user_handler
import transport/http/protocol/api_errors
import transport/transport_context
import wisp

pub fn handle(
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
  body: String,
) -> wisp.Response {
  case decode_bio(body) {
    Error(Nil) ->
      api_errors.response(
        status.bad_request,
        "invalid_body",
        "Bio must be a string",
        context,
      )
    Ok(bio) ->
      case profile.validate_bio(bio) {
        profile.BioTooLong ->
          api_errors.response(
            status.bad_request,
            api_error.bio_too_long_code,
            api_error.bio_too_long_message,
            context,
          )
        profile.BioValid -> update_profile_bio(dependencies, context, bio)
      }
  }
}

fn update_profile_bio(
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
  bio: String,
) -> wisp.Response {
  case transport_context.principal(context) {
    option.None -> unauthorized(context)
    option.Some(principal) ->
      case
        user.update_bio(
          dependencies.postgres,
          principal.user_id,
          bio,
          dependencies.config.postgres.query_timeout,
        )
      {
        Ok(Nil) ->
          case
            user.find(
              dependencies.postgres,
              principal.user_id,
              dependencies.config.postgres.query_timeout,
            )
          {
            Ok(option.Some(profile)) -> user_handler.response(profile)
            Ok(option.None) -> unauthorized(context)
            Error(_) -> database_error(context)
          }
        Error(_) -> database_error(context)
      }
  }
}

fn decode_bio(body: String) -> Result(String, Nil) {
  json.parse(body, bio_decoder())
  |> result.map_error(fn(_) { Nil })
}

fn bio_decoder() -> decode.Decoder(String) {
  decode.field("bio", decode.string, decode.success)
}

fn unauthorized(context: transport_context.TransportContext) -> wisp.Response {
  api_errors.response(
    status.unauthorized,
    api_error.unauthorized_code,
    api_error.unauthorized_message,
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
