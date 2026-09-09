import application/access
import application/services/session as session_service
import gleam/http/request
import gleam/list
import gleam/option
import logging
import observability/logger
import observability/metrics
import transport/transport_context

pub const cookie_name = "roxy_session"

pub fn principal(
  http_request: request.Request(body),
  secret_key_base: String,
  context: transport_context.TransportContext,
) -> option.Option(access.Principal) {
  case
    http_request
    |> request.get_cookies
    |> list.key_find(cookie_name)
  {
    Ok(signed_value) ->
      case session_service.verify(signed_value, secret_key_base) {
        Ok(principal) -> option.Some(principal)
        Error(reason) -> {
          metrics.record(context.metrics, metrics.SessionInvalid)
          logger.write(logging.Warning, "session_invalid", [
            #("request_id", transport_context.request_id(context)),
            #("reason", verification_reason(reason)),
          ])
          option.None
        }
      }
    Error(_) -> {
      metrics.record(context.metrics, metrics.SessionMissing)
      logger.write(logging.Debug, "session_missing", [
        #("request_id", transport_context.request_id(context)),
      ])
      option.None
    }
  }
}

fn verification_reason(reason: session_service.VerificationError) -> String {
  case reason {
    session_service.InvalidSignature -> "invalid_signature"
    session_service.InvalidPayload -> "invalid_payload"
    session_service.EmptyPrincipal -> "empty_principal"
  }
}
