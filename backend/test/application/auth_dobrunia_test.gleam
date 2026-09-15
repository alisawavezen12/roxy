import application/services/auth/dobrunia
import config/auth
import gleam/option
import gleam/string
import gleeunit/should

fn config() -> auth.AuthConfig {
  auth.AuthConfig(
    client_id: "roxy web",
    redirect_uri: "https://api.example.com/auth/sso/callback",
    frontend_url: "http://localhost:1234",
    token_encryption_key: "test-token-encryption-key-with-sufficient-length",
  )
}

pub fn authorize_url_contains_encoded_contract_values_test() {
  let assert Ok(url) = dobrunia.authorize_url(config(), "state+/=")

  url
  |> string.contains("response_type=code")
  |> should.equal(True)
  url
  |> string.contains("client_id=roxy%20web")
  |> should.equal(True)
  url
  |> string.contains(
    "redirect_uri=https%3A%2F%2Fapi.example.com%2Fauth%2Fsso%2Fcallback",
  )
  |> should.equal(True)
  url
  |> string.contains("state=state+%2F%3D")
  |> should.equal(True)
}

pub fn exchange_response_decodes_required_contract_test() {
  let body =
    "{\"accessToken\":\"access\",\"refreshToken\":\"refresh\",\"user\":{\"id\":\"user-1\",\"email\":\"user@example.com\",\"firstName\":\"Dobrynya\",\"lastName\":null,\"avatarUrl\":null},\"session\":{\"id\":\"provider-session\",\"clientId\":\"client\"}}"
  let assert Ok(tokens) = dobrunia.decode_tokens(body)

  tokens.access_token |> should.equal("access")
  tokens.refresh_token |> should.equal("refresh")

  tokens.provider_session_id |> should.equal("provider-session")
}

pub fn profile_response_decodes_username_and_avatar_test() {
  let body =
    "{\"user\":{\"id\":\"user-1\",\"email\":\"user@example.com\",\"username\":\"sentry\",\"firstName\":null,\"lastName\":null,\"avatarUrl\":\"https://cdn.example/avatar.png\"}}"
  let assert Ok(user) = dobrunia.decode_user(body)

  user.username |> should.equal(option.Some("sentry"))
  user.avatar_url
  |> should.equal(option.Some("https://cdn.example/avatar.png"))
}

pub fn refresh_response_decodes_rotated_pair_without_user_test() {
  let body = "{\"accessToken\":\"new-access\",\"refreshToken\":\"new-refresh\"}"
  let assert Ok(tokens) = dobrunia.decode_token_pair(body)

  tokens.access_token |> should.equal("new-access")
  tokens.refresh_token |> should.equal("new-refresh")
}

pub fn malformed_provider_response_is_rejected_test() {
  dobrunia.decode_tokens(
    "{\"accessToken\":\"access\",\"refreshToken\":\"refresh\",\"user\":{}}",
  )
  |> should.equal(Error(Nil))
}
