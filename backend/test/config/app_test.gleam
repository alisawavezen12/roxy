import config/app
import config/environment
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
  |> should.equal(8080)

  config.secret_key_base
  |> should.equal(
    "development-secret-key-base-that-is-long-enough-for-wisp-xxxxxxxxxxxx",
  )

  config.origins.allowed
  |> should.equal(["http://localhost:1234"])
  config.session.ttl_seconds
  |> should.equal(86_400)
  config.session.cookie_secure
  |> should.equal(False)
}

pub fn production_reads_environment_test() {
  envoy.set("APP_ENV", "production")
  envoy.set("PORT", "9090")
  envoy.set("DATABASE_URL", "postgres://user:password@db/app")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")
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
  envoy.set(
    "SECRET_KEY_BASE",
    "production-secret-key-base-that-is-long-enough-for-wisp-xxxxxxxxxxxx",
  )
  envoy.unset("CORS_ALLOWED_ORIGINS")

  app.load()
  |> should.equal(Error(
    "CORS_ALLOWED_ORIGINS environment variable is required in production",
  ))
}

pub fn invalid_session_ttl_fails_fast_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com")
  envoy.set("SESSION_TTL_SECONDS", "30")

  app.load()
  |> should.equal(Error("SESSION_TTL_SECONDS must be between 60 and 2592000"))
}

pub fn production_rejects_empty_origin_list_entry_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com,")

  app.load()
  |> should.equal(Error(
    "CORS_ALLOWED_ORIGINS must contain only HTTP origins in the form scheme://host[:port]; invalid value: ",
  ))
}

pub fn production_rejects_non_origin_cors_value_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com/path")

  app.load()
  |> should.equal(Error(
    "CORS_ALLOWED_ORIGINS must contain only HTTP origins in the form scheme://host[:port]; invalid value: https://app.example.com/path",
  ))
}

pub fn production_rejects_empty_port_test() {
  configure_production()
  envoy.set("CORS_ALLOWED_ORIGINS", "https://app.example.com:")

  app.load()
  |> should.equal(Error(
    "CORS_ALLOWED_ORIGINS must contain only HTTP origins in the form scheme://host[:port]; invalid value: https://app.example.com:",
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
  envoy.set(
    "SECRET_KEY_BASE",
    "production-secret-key-base-that-is-long-enough-for-wisp-xxxxxxxxxxxx",
  )
}
