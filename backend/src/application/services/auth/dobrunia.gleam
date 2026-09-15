import application/services/user
import config/auth
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/option
import gleam/result
import gleam/uri

pub type Tokens {
  Tokens(
    access_token: String,
    refresh_token: String,
    provider_session_id: String,
  )
}

pub type TokenPair {
  TokenPair(access_token: String, refresh_token: String)
}

pub type Error {
  Configuration
  Transport
  Rejected(status: Int)
  InvalidResponse
}

pub fn authorize_url(
  config: auth.AuthConfig,
  state: String,
) -> Result(String, Error) {
  let auth.AuthConfig(client_id:, redirect_uri:, ..) = config
  use http_request <- result.try(
    request.to(auth.provider_base_url <> "/oauth/authorize")
    |> result.map_error(fn(_) { Configuration }),
  )
  Ok(
    http_request
    |> request.set_query([
      #("response_type", "code"),
      #("client_id", client_id),
      #("redirect_uri", redirect_uri),
      #("state", state),
    ])
    |> request.to_uri
    |> uri.to_string,
  )
}

pub fn exchange_code(
  config: auth.AuthConfig,
  code: String,
) -> Result(Tokens, Error) {
  let auth.AuthConfig(client_id:, redirect_uri:, ..) = config
  post(
    auth.provider_base_url <> "/oauth/token",
    json.object([
      #("grant_type", json.string("authorization_code")),
      #("code", json.string(code)),
      #("redirect_uri", json.string(redirect_uri)),
      #("client_id", json.string(client_id)),
    ]),
    tokens_decoder(),
  )
}

pub fn user(access_token: String) -> Result(user.User, Error) {
  use http_request <- result.try(
    request.to(auth.provider_base_url <> "/auth/me")
    |> result.map_error(fn(_) { Configuration }),
  )
  let http_request =
    http_request
    |> request.set_header("authorization", "Bearer " <> access_token)
    |> request.set_header("accept", "application/json")
  use response <- result.try(send(http_request))
  case response.status >= 200 && response.status < 300 {
    True ->
      json.parse(response.body, profile_decoder())
      |> result.map_error(fn(_) { InvalidResponse })
    False -> Error(Rejected(response.status))
  }
}

pub fn refresh(refresh_token: String) -> Result(TokenPair, Error) {
  post(
    auth.provider_base_url <> "/auth/refresh",
    json.object([#("refreshToken", json.string(refresh_token))]),
    token_pair_decoder(),
  )
}

pub fn logout(refresh_token: String) -> Result(Nil, Error) {
  use http_request <- result.try(
    request.to(auth.provider_base_url <> "/auth/logout")
    |> result.map_error(fn(_) { Configuration }),
  )
  let http_request =
    http_request
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("accept", "application/json")
    |> request.set_body(
      json.object([#("refreshToken", json.string(refresh_token))])
      |> json.to_string,
    )
  use response <- result.try(send(http_request))
  case response.status >= 200 && response.status < 300 {
    True -> Ok(Nil)
    False -> Error(Rejected(response.status))
  }
}

fn post(
  url: String,
  body: json.Json,
  decoder: decode.Decoder(value),
) -> Result(value, Error) {
  use http_request <- result.try(
    request.to(url) |> result.map_error(fn(_) { Configuration }),
  )
  let http_request =
    http_request
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("accept", "application/json")
    |> request.set_body(json.to_string(body))
  use response <- result.try(send(http_request))
  case response.status >= 200 && response.status < 300 {
    True ->
      json.parse(response.body, decoder)
      |> result.map_error(fn(_) { InvalidResponse })
    False -> Error(Rejected(response.status))
  }
}

fn send(http_request: request.Request(String)) {
  httpc.configure()
  |> httpc.timeout(auth.request_timeout_ms)
  |> httpc.follow_redirects(False)
  |> httpc.dispatch(http_request)
  |> result.map_error(fn(_) { Transport })
}

pub fn decode_tokens(body: String) -> Result(Tokens, Nil) {
  json.parse(body, tokens_decoder())
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_user(body: String) -> Result(user.User, Nil) {
  json.parse(body, profile_decoder())
  |> result.map_error(fn(_) { Nil })
}

pub fn decode_token_pair(body: String) -> Result(TokenPair, Nil) {
  json.parse(body, token_pair_decoder())
  |> result.map_error(fn(_) { Nil })
}

fn tokens_decoder() -> decode.Decoder(Tokens) {
  use access_token <- decode.field("accessToken", decode.string)
  use refresh_token <- decode.field("refreshToken", decode.string)
  use provider_session_id <- decode.field("session", session_decoder())
  decode.success(Tokens(access_token:, refresh_token:, provider_session_id:))
}

fn token_pair_decoder() -> decode.Decoder(TokenPair) {
  use access_token <- decode.field("accessToken", decode.string)
  use refresh_token <- decode.field("refreshToken", decode.string)
  decode.success(TokenPair(access_token:, refresh_token:))
}

fn user_decoder() -> decode.Decoder(user.User) {
  use id <- decode.field("id", decode.string)
  use email <- decode.field("email", decode.string)
  use username <- decode.optional_field(
    "username",
    option.None,
    decode.optional(decode.string),
  )
  use first_name <- decode.optional_field(
    "firstName",
    option.None,
    decode.optional(decode.string),
  )
  use last_name <- decode.optional_field(
    "lastName",
    option.None,
    decode.optional(decode.string),
  )
  use avatar_url <- decode.optional_field(
    "avatarUrl",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(user.User(
    id:,
    email:,
    username:,
    first_name:,
    last_name:,
    avatar_url:,
  ))
}

fn profile_decoder() -> decode.Decoder(user.User) {
  decode.field("user", user_decoder(), decode.success)
}

fn session_decoder() -> decode.Decoder(String) {
  decode.field("id", decode.string, decode.success)
}
