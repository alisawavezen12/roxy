import application/messages
import config/app
import config/defaults
import config/environment
import config/session
import envoy
import gleeunit/should

pub fn development_uses_defaults_test() {
  envoy.set("APP_ENV", "development")
  envoy.set("PORT", "9999")
  envoy.set("DATABASE_URL", "postgres://production/database")
  envoy.set("SECRET_KEY_BASE", "production-secret")
  envoy.unset("CORS_ALLOWED_ORIGINS")

  let assert Ok(config) = app.load()

  config.environment
  |> should.equal(environment.Development)

  config.port
  |> should.equal(defaults.port)

  config.secret_key_base
  |> should.equal(
    defaults.secret_key_base,
  )

  config.origins.allowed
  |> should.equal([defaults.cors_allowed_origins])
  config.session.ttl_seconds
  |> should.equal(session.default_ttl_seconds)
  config.session.cookie_secure
  |> should.equal(False)
}

pub fn production_reads_environment_test() {
  envoy.set("APP_ENV", "production")
  envoy.set("PORT", "9090")
  envoy.set("DATABASE_URL", "postgres://user:password@db/app")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")
  envoy.set("DATABASE_STATEMENT_TIMEOUT_MS", "4000")
  envoy.set("DATABASE_LOCK_TIMEOUT_MS", "1000")
  envoy.set("DATABASE_TRANSACTION_TIMEOUT_MS", "15000")
  envoy.set("DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS", "5000")
  envoy.set(
    "SECRET_KEY_BASE",
    "production-secret-key-base-that-is-long-enough-for-wisp-xxxxxxxxxxxx",
  )
  envoy.set(
    "CORS_ALLOWED_ORIGINS",
    "https://app.example.com, https://admin.example.com:8443",
  )
  envoy.set("PUBLIC_BASE_URL", "https://app.example.com")
  envoy.set("TRUSTED_PROXY_IPS", "10.0.0.2")
  envoy.set("TRUSTED_INTERNAL_IPS", "172.18.0.2")

  let assert Ok(config) = app.load()

  config.environment
  |> should.equal(environment.Production)

  config.port
  |> should.equal(9090)

  config.origins.allowed
  |> should.equal([
    "https://app.example.com",
    "https://admin.example.com:8443",
  ])
  config.session.cookie_secure
  |> should.equal(True)
}

pub fn production_requires_cors_origins_test() {
  envoy.set("APP_ENV", "production")
  envoy.set("PUBLIC_BASE_URL", "https://app.example.com")
  envoy.set("TRUSTED_PROXY_IPS", "10.0.0.2")
  envoy.set("TRUSTED_INTERNAL_IPS", "172.18.0.2")
  envoy.set("PORT", "9090")
  envoy.set("DATABASE_URL", "postgres://user:password@db/app")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")
  envoy.set("DATABASE_STATEMENT_TIMEOUT_MS", "4000")
  envoy.set("DATABASE_LOCK_TIMEOUT_MS", "1000")
  envoy.set("DATABASE_TRANSACTION_TIMEOUT_MS", "15000")
  envoy.set("DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS", "5000")
  envoy.set(
    "SECRET_KEY_BASE",
    "production-secret-key-base-that-is-long-enough-for-wisp-xxxxxxxxxxxx",
  )
  envoy.unset("CORS_ALLOWED_ORIGINS")

  app.load()
  |> should.equal(Error(
    messages.cors_origins_required,
  ))
}

pub fn invalid_session_ttl_fails_fast_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com")
  envoy.set("SESSION_TTL_SECONDS", "30")

  app.load()
  |> should.equal(Error(messages.session_ttl_invalid))
}

pub fn production_rejects_empty_origin_list_entry_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com,")

  app.load()
  |> should.equal(Error(
    messages.invalid_cors_origin(""),
  ))
}

pub fn production_rejects_non_origin_cors_value_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com/path")

  app.load()
  |> should.equal(Error(
    messages.invalid_cors_origin("https://app.example.com/path"),
  ))
}

pub fn production_rejects_empty_port_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com:")

  app.load()
  |> should.equal(Error(
    messages.invalid_cors_origin("https://app.example.com:"),
  ))
}

fn configure_production() -> Nil {
  envoy.set("APP_ENV", "production")
  envoy.set("PUBLIC_BASE_URL", "https://app.example.com")
  envoy.set("TRUSTED_PROXY_IPS", "10.0.0.2")
  envoy.set("TRUSTED_INTERNAL_IPS", "172.18.0.2")
  envoy.set("PORT", "9090")
  envoy.set("DATABASE_URL", "postgres://user:password@db/app")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")
  envoy.set("DATABASE_STATEMENT_TIMEOUT_MS", "4000")
  envoy.set("DATABASE_LOCK_TIMEOUT_MS", "1000")
  envoy.set("DATABASE_TRANSACTION_TIMEOUT_MS", "15000")
  envoy.set("DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS", "5000")
  envoy.set(
    "SECRET_KEY_BASE",
    "production-secret-key-base-that-is-long-enough-for-wisp-xxxxxxxxxxxx",
  )
}
