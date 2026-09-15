import application/dependencies
import application/services/auth/authentication
import application/services/auth/dobrunia
import application/services/auth/oauth_state
import application/services/auth/session as session_service
import application/services/user
import config/auth
import config/session as session_config
import gleam/http/cookie
import gleam/http/request
import gleam/http/response as http_response
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import logging
import observability/logger
import pog
import security/token_cipher
import shared/api/error as api_error
import transport/http/protocol/api_errors
import transport/http/protocol/status
import transport/session
import transport/transport_context
import wisp

pub const state_cookie_name = "roxy_oauth_state"

pub fn start(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  let config = dependencies.config
  let return_to = return_to(http_request, config.auth)
  case
    oauth_state.create(
      dependencies.postgres,
      auth.state_ttl_seconds,
      return_to,
      config.postgres.query_timeout,
    )
  {
    Error(_) -> database_error(context)
    Ok(#(state, binding)) ->
      case dobrunia.authorize_url(config.auth, state) {
        Error(_) -> provider_error(context)
        Ok(url) ->
          wisp.redirect(to: url)
          |> set_state_cookie(binding, config.session)
      }
  }
}

pub fn callback(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  let config = dependencies.config
  let params = request.get_query(http_request) |> result.unwrap([])
  let base_response =
    clear_state_cookie(wisp.response(status.ok), config.session)
  case
    list.key_find(params, "code"),
    list.key_find(params, "state"),
    http_request |> request.get_cookies |> list.key_find(state_cookie_name)
  {
    Ok(code), Ok(state), Ok(binding) ->
      complete_callback(
        http_request,
        dependencies,
        context,
        base_response,
        code,
        state,
        binding,
      )
    _, _, _ ->
      redirect_error(base_response, config.auth, "/", "invalid_callback")
  }
}

pub fn logout(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  let response =
    session.clear_cookie(
      wisp.no_content(),
      http_request,
      dependencies.config.session,
    )
  case session.token(http_request) {
    option.None -> response
    option.Some(local_token) ->
      case
        authentication.logout_session(
          dependencies.postgres,
          dependencies.config.auth,
          local_token,
          dependencies.config.postgres.query_timeout,
        )
      {
        Ok(Nil) -> response
        Error(authentication.Auth(_))
        | Error(authentication.InvalidStoredToken) ->
          revoke_locally(response, local_token, dependencies, context)
        Error(authentication.Database(_)) -> database_error(context)
      }
  }
}

pub fn refresh(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case session.token(http_request) {
    option.None -> unauthorized(context)
    option.Some(local_token) ->
      case
        authentication.refresh_session(
          dependencies.postgres,
          dependencies.config.auth,
          local_token,
          dependencies.config.postgres.query_timeout,
        )
      {
        Ok(Nil) -> wisp.no_content()
        Error(authentication.Auth(dobrunia.Rejected(401)))
        | Error(authentication.InvalidStoredToken) ->
          clear_invalid_session(http_request, dependencies, context)
        Error(authentication.Auth(_)) -> provider_error(context)
        Error(authentication.Database(_)) -> database_error(context)
      }
  }
}

fn complete_callback(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
  base_response: wisp.Response,
  code: String,
  state: String,
  binding: String,
) -> wisp.Response {
  let config = dependencies.config
  case
    oauth_state.consume(
      dependencies.postgres,
      state,
      binding,
      config.postgres.query_timeout,
    )
  {
    Error(_) -> redirect_error(base_response, config.auth, "/", "server_error")
    Ok(oauth_state.NotFound) ->
      redirect_error(base_response, config.auth, "/", "invalid_callback")
    Ok(oauth_state.ReturnTo(return_to)) ->
      case dobrunia.exchange_code(config.auth, code) {
        Error(_) ->
          redirect_error(
            base_response,
            config.auth,
            return_to,
            "provider_error",
          )
        Ok(tokens) ->
          case dobrunia.user(tokens.access_token) {
            Error(_) ->
              redirect_error(
                base_response,
                config.auth,
                return_to,
                "profile_error",
              )
            Ok(profile) ->
              persist_login(
                http_request,
                dependencies,
                context,
                base_response,
                tokens,
                profile,
                return_to,
              )
          }
      }
  }
}

fn persist_login(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  _context: transport_context.TransportContext,
  base_response: wisp.Response,
  tokens: dobrunia.Tokens,
  authenticated_user: user.User,
  return_to: String,
) -> wisp.Response {
  let config = dependencies.config
  let auth.AuthConfig(token_encryption_key:, ..) = config.auth
  let encryption_key = token_cipher.derive_key(token_encryption_key)
  let persisted =
    pog.transaction(dependencies.postgres, fn(connection) {
      use user_id <- result.try(user.upsert(
        connection,
        authenticated_user,
        config.postgres.query_timeout,
      ))
      session_service.create_with_provider(
        connection,
        user_id,
        tokens.provider_session_id,
        token_cipher.encrypt(tokens.access_token, encryption_key),
        token_cipher.encrypt(tokens.refresh_token, encryption_key),
        config.session.ttl_seconds,
        config.postgres.query_timeout,
      )
    })
  case persisted {
    Error(_) ->
      redirect_error(base_response, config.auth, return_to, "login_failed")
    Ok(local_token) ->
      session.set_cookie(
        base_response,
        http_request,
        local_token,
        config.session,
      )
      |> redirect_to(config.auth, return_to)
  }
}

fn return_to(http_request: wisp.Request, config: auth.AuthConfig) -> String {
  let params = request.get_query(http_request) |> result.unwrap([])
  case list.key_find(params, "return_to") {
    Error(_) -> config.frontend_url <> "/"
    Ok(value) ->
      case allowed_return_to(value, config.frontend_url) {
        True -> value
        False -> config.frontend_url <> "/"
      }
  }
}

pub fn allowed_return_to(value: String, frontend_url: String) -> Bool {
  case uri.parse(value), uri.parse(frontend_url) {
    Ok(uri.Uri(userinfo: option.None, ..) as value), Ok(frontend) ->
      case uri.origin(value), uri.origin(frontend) {
        Ok(value_origin), Ok(frontend_origin) -> value_origin == frontend_origin
        _, _ -> False
      }
    _, _ -> False
  }
}

fn redirect_to(
  response: wisp.Response,
  _config: auth.AuthConfig,
  return_to: String,
) -> wisp.Response {
  copy_cookies(wisp.redirect(to: return_to), response)
}

fn redirect_error(
  response: wisp.Response,
  config: auth.AuthConfig,
  return_to: String,
  code: String,
) -> wisp.Response {
  let target = case allowed_return_to(return_to, config.frontend_url) {
    True -> return_to
    False -> config.frontend_url <> "/"
  }
  let separator = case string.contains(target, "?") {
    True -> "&"
    False -> "?"
  }
  redirect_to(
    response,
    config,
    target <> separator <> "auth_error=" <> uri.percent_encode(code),
  )
}

fn copy_cookies(
  response: wisp.Response,
  source: wisp.Response,
) -> wisp.Response {
  source.headers
  |> list.filter(fn(header) { header.0 == "set-cookie" })
  |> list.fold(response, fn(response, header) {
    http_response.prepend_header(response, "set-cookie", header.1)
  })
}

fn set_state_cookie(
  response: wisp.Response,
  binding: String,
  session_config: session_config.SessionConfig,
) -> wisp.Response {
  http_response.set_cookie(
    response,
    state_cookie_name,
    binding,
    cookie.Attributes(
      max_age: option.Some(auth.state_ttl_seconds),
      domain: option.None,
      path: option.Some("/auth/sso/callback"),
      secure: session_config.cookie_secure,
      http_only: True,
      same_site: option.Some(cookie.Lax),
    ),
  )
}

fn clear_state_cookie(
  response: wisp.Response,
  session_config: session_config.SessionConfig,
) -> wisp.Response {
  http_response.expire_cookie(
    response,
    state_cookie_name,
    cookie.Attributes(
      max_age: option.None,
      domain: option.None,
      path: option.Some("/auth/sso/callback"),
      secure: session_config.cookie_secure,
      http_only: True,
      same_site: option.Some(cookie.Lax),
    ),
  )
}

fn revoke_locally(
  response: wisp.Response,
  local_token: String,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case
    session_service.revoke(
      dependencies.postgres,
      local_token,
      dependencies.config.postgres.query_timeout,
    )
  {
    Ok(Nil) -> response
    Error(_) -> database_error(context)
  }
}

fn clear_invalid_session(
  http_request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  let response = unauthorized(context)
  case session.revoke(response, http_request, dependencies) {
    Ok(response) -> response
    Error(_) ->
      session.clear_cookie(response, http_request, dependencies.config.session)
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
  logger.write(logging.Warning, "dobrunia_auth_request_failed", [
    #("request_id", transport_context.request_id(context)),
  ])
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
  logger.write(logging.Error, "authentication_store_failed", [
    #("request_id", transport_context.request_id(context)),
  ])
  api_errors.response(
    status.internal_server_error,
    api_error.internal_error_code,
    api_error.internal_error_message,
    context,
  )
}
