import application/messages
import config/environment
import envoy
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{Uri}

pub const provider_base_url = "https://dobrunia-auth.na4u.ru"

pub const frontend_url_development = "http://localhost:1234"

pub const state_ttl_seconds = 600

pub const request_timeout_ms = 3000

pub type AuthConfig {
  AuthConfig(
    client_id: String,
    redirect_uri: String,
    frontend_url: String,
    token_encryption_key: String,
  )
}

pub fn load(
  environment: environment.Environment,
  public_base_url: String,
) -> Result(AuthConfig, String) {
  use client_id <- result.try(required("DOBRUNIA_AUTH_CLIENT_ID"))
  use client_id <- result.try(validate_client_id(client_id))
  use token_encryption_key <- result.try(required("AUTH_TOKEN_ENCRYPTION_KEY"))
  use token_encryption_key <- result.try(validate_encryption_key(
    token_encryption_key,
  ))
  use frontend_url <- result.try(load_frontend_url(environment))

  Ok(AuthConfig(
    client_id:,
    redirect_uri: callback_uri(public_base_url),
    frontend_url:,
    token_encryption_key:,
  ))
}

pub fn callback_uri(public_base_url: String) -> String {
  without_trailing_slash(public_base_url) <> "/auth/sso/callback"
}

fn load_frontend_url(
  environment: environment.Environment,
) -> Result(String, String) {
  case environment {
    environment.Development -> Ok(frontend_url_development)
    environment.Production -> {
      use value <- result.try(required("FRONTEND_URL"))
      validate_frontend_url(value)
    }
  }
}

fn validate_frontend_url(value: String) -> Result(String, String) {
  case uri.parse(value) {
    Ok(Uri(
      scheme: option.Some("https"),
      userinfo: option.None,
      host: option.Some(host),
      path: path,
      query: option.None,
      fragment: option.None,
      ..,
    ))
      if host != "" && { path == "" || path == "/" }
    -> Ok(without_trailing_slash(value))
    _ -> Error(messages.frontend_url_invalid)
  }
}

fn validate_client_id(value: String) -> Result(String, String) {
  let value = string.trim(value)
  case value != "" && string.length(value) <= 255 {
    True -> Ok(value)
    False -> Error(messages.dobrunia_auth_client_id_invalid)
  }
}

fn validate_encryption_key(value: String) -> Result(String, String) {
  case string.length(value) >= 32 {
    True -> Ok(value)
    False -> Error(messages.auth_token_encryption_key_too_short)
  }
}

fn required(name: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) ->
      case string.trim(value) {
        "" -> Error(messages.required(name))
        value -> Ok(value)
      }
    Error(_) -> Error(messages.required(name))
  }
}

fn without_trailing_slash(value: String) -> String {
  case string.ends_with(value, "/") {
    True -> string.drop_end(value, 1)
    False -> value
  }
}
