import application/messages
import config/auth
import config/environment
import envoy
import gleeunit/should

pub fn development_requires_sso_client_id_test() {
  envoy.unset("DOBRUNIA_AUTH_CLIENT_ID")
  envoy.set(
    "AUTH_TOKEN_ENCRYPTION_KEY",
    "test-token-encryption-key-with-sufficient-length",
  )

  auth.load(environment.Development, "http://localhost:8080")
  |> should.equal(Error(messages.required("DOBRUNIA_AUTH_CLIENT_ID")))
}

pub fn development_requires_token_encryption_key_test() {
  envoy.set("DOBRUNIA_AUTH_CLIENT_ID", "roxy-web")
  envoy.unset("AUTH_TOKEN_ENCRYPTION_KEY")

  auth.load(environment.Development, "http://localhost:8080")
  |> should.equal(Error(messages.required("AUTH_TOKEN_ENCRYPTION_KEY")))
}

pub fn development_uses_url_constants_test() {
  configure_secrets()
  envoy.set("FRONTEND_URL", "https://ignored.example.com")

  let assert Ok(config) =
    auth.load(environment.Development, "http://localhost:8080")

  config.client_id |> should.equal("roxy-web")
  config.redirect_uri
  |> should.equal("http://localhost:8080/auth/sso/callback")
  config.frontend_url |> should.equal(auth.frontend_url_development)
  auth.provider_base_url |> should.equal("https://dobrunia-auth.na4u.ru")
  auth.request_timeout_ms |> should.equal(3000)
}

pub fn production_uses_explicit_public_urls_test() {
  configure_secrets()
  envoy.set("FRONTEND_URL", "https://app.example.com/")

  let assert Ok(config) =
    auth.load(environment.Production, "https://api.example.com/")

  config.frontend_url |> should.equal("https://app.example.com")
  config.redirect_uri
  |> should.equal("https://api.example.com/auth/sso/callback")
}

pub fn production_rejects_http_frontend_url_test() {
  configure_secrets()
  envoy.set("FRONTEND_URL", "http://app.example.com")

  auth.load(environment.Production, "https://api.example.com")
  |> should.equal(Error(messages.frontend_url_invalid))
}

pub fn short_encryption_key_is_rejected_test() {
  envoy.set("DOBRUNIA_AUTH_CLIENT_ID", "roxy-web")
  envoy.set("AUTH_TOKEN_ENCRYPTION_KEY", "short")

  auth.load(environment.Development, "http://localhost:8080")
  |> should.equal(Error(messages.auth_token_encryption_key_too_short))
}

fn configure_secrets() -> Nil {
  envoy.set("DOBRUNIA_AUTH_CLIENT_ID", "roxy-web")
  envoy.set(
    "AUTH_TOKEN_ENCRYPTION_KEY",
    "test-token-encryption-key-with-sufficient-length",
  )
}
