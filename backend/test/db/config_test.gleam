import config/environment
import db/config
import envoy
import gleeunit/should

pub fn development_uses_defaults_test() {
  envoy.set("APP_ENV", "development")
  envoy.set("DATABASE_URL", "postgres://production/database")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")

  let assert Ok(postgres_config) = config.load(environment.Development)

  postgres_config.url
  |> should.equal("postgres://roxy:roxy@postgres:5432/roxy")

  postgres_config.pool_size
  |> should.equal(10)

  postgres_config.query_timeout
  |> should.equal(5000)
}

pub fn production_reads_environment_test() {
  envoy.set("APP_ENV", "production")
  envoy.set("DATABASE_URL", "postgres://user:password@db/app")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")

  let assert Ok(postgres_config) = config.load(environment.Production)

  postgres_config.url
  |> should.equal("postgres://user:password@db/app")

  postgres_config.pool_size
  |> should.equal(20)

  postgres_config.query_timeout
  |> should.equal(7000)
}
