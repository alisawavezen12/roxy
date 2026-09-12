import application/access
import application/dependencies as app_dependencies
import application/services/session as session_service
import config/session as session_config
import gleam/http/cookie
import gleam/http/request
import gleam/http/response as http_response
import gleam/list
import gleam/option
import gleam/result
import logging
import observability/logger
import observability/metrics
import pog
import transport/transport_context
import wisp

pub const cookie_name = "roxy_session"

pub fn issue(
  response: wisp.Response,
  http_request: request.Request(body),
  dependencies: app_dependencies.Dependencies,
  user_id: String,
) -> Result(wisp.Response, pog.QueryError) {
  issue_with_permissions(response, http_request, dependencies, user_id, [])
}

pub fn issue_with_permissions(
  response: wisp.Response,
  http_request: request.Request(body),
  dependencies: app_dependencies.Dependencies,
  user_id: String,
  permissions: List(String),
) -> Result(wisp.Response, pog.QueryError) {
  let config = app_dependencies.config(dependencies)
  use token <- result.try(session_service.create_with_permissions(
    app_dependencies.postgres(dependencies),
    user_id,
    permissions,
    config.session.ttl_seconds,
    config.postgres.query_timeout,
  ))
  Ok(set_cookie(response, http_request, token, config.session))
}

pub fn revoke(
  response: wisp.Response,
  http_request: request.Request(body),
  dependencies: app_dependencies.Dependencies,
) -> Result(wisp.Response, pog.QueryError) {
  let config = app_dependencies.config(dependencies)
  let response = clear_cookie(response, http_request, config.session)
  case http_request |> request.get_cookies |> list.key_find(cookie_name) {
    Error(_) -> Ok(response)
    Ok(token) -> {
      use _ <- result.try(session_service.revoke(
        app_dependencies.postgres(dependencies),
        token,
        config.postgres.query_timeout,
      ))
      Ok(response)
    }
  }
}

pub fn principal(
  http_request: request.Request(body),
  dependencies: app_dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> option.Option(access.Principal) {
  case http_request |> request.get_cookies |> list.key_find(cookie_name) {
    Ok(token) ->
      case
        session_service.verify(
          app_dependencies.postgres(dependencies),
          token,
          app_dependencies.config(dependencies).postgres.query_timeout,
        )
      {
        Ok(principal) -> option.Some(principal)
        Error(reason) -> {
          case reason {
            session_service.Database(_) -> {
              metrics.record(context.metrics, metrics.SessionStoreFailed)
              logger.write(logging.Error, "session_store_unavailable", [
                #("request_id", transport_context.request_id(context)),
              ])
            }
            _ -> {
              metrics.record(context.metrics, metrics.SessionInvalid)
              logger.write(logging.Warning, "session_invalid", [
                #("request_id", transport_context.request_id(context)),
                #("reason", verification_reason(reason)),
              ])
            }
          }
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

pub fn set_cookie(
  response: wisp.Response,
  _request: request.Request(body),
  token: String,
  config: session_config.SessionConfig,
) -> wisp.Response {
  http_response.set_cookie(
    response,
    cookie_name,
    token,
    cookie.Attributes(
      max_age: option.Some(config.ttl_seconds),
      domain: option.None,
      path: option.Some("/"),
      secure: config.cookie_secure,
      http_only: True,
      same_site: option.Some(cookie.Lax),
    ),
  )
}

pub fn clear_cookie(
  response: wisp.Response,
  _request: request.Request(body),
  config: session_config.SessionConfig,
) -> wisp.Response {
  http_response.expire_cookie(
    response,
    cookie_name,
    cookie.Attributes(
      max_age: option.None,
      domain: option.None,
      path: option.Some("/"),
      secure: config.cookie_secure,
      http_only: True,
      same_site: option.Some(cookie.Lax),
    ),
  )
}

fn verification_reason(reason: session_service.VerificationError) -> String {
  case reason {
    session_service.InvalidToken -> "invalid_token"
    session_service.Expired -> "expired"
    session_service.Revoked -> "revoked"
    session_service.Database(_) -> "database_error"
  }
}
