import config/app
import config/environment
import envoy
import gleeunit/should

pub fn development_uses_defaults_test() {
  envoy.set("APP_ENV", "development")
  envoy.set("PORT", "9999")
  envoy.set("DATABASE_URL", "postgres://production/database")
  envoy.set("SECRET_KEY_BASE", "production-secret")

  let assert Ok(config) = app.load()

  config.environment
  |> should.equal(environment.Development)

  config.port
  |> should.equal(8080)

  config.secret_key_base
  |> should.equal(
    "development-secret-key-base-that-is-long-enough-for-wisp-xxxxxxxxxxxx",
  )
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

  let assert Ok(config) = app.load()

  config.environment
  |> should.equal(environment.Production)

  config.port
  |> should.equal(9090)
}
