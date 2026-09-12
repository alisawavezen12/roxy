import application/messages
import config/environment
import db/config
import db/defaults as db_defaults
import envoy
import gleeunit/should

pub fn development_uses_defaults_test() {
  envoy.set("APP_ENV", "development")
  envoy.set("DATABASE_URL", "postgres://production/database")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")

  let assert Ok(postgres_config) = config.load(environment.Development)

  postgres_config.url
  |> should.equal(db_defaults.url)

  postgres_config.pool_size
  |> should.equal(db_defaults.pool_size)

  postgres_config.query_timeout
  |> should.equal(db_defaults.query_timeout)
  postgres_config.statement_timeout
  |> should.equal(db_defaults.statement_timeout)
  postgres_config.lock_timeout
  |> should.equal(db_defaults.lock_timeout)
  postgres_config.transaction_timeout
  |> should.equal(db_defaults.transaction_timeout)
  postgres_config.idle_in_transaction_timeout
  |> should.equal(db_defaults.idle_in_transaction_timeout)
}

pub fn production_rejects_inconsistent_timeout_budgets_test() {
  envoy.set("APP_ENV", "production")
  envoy.set("DATABASE_URL", "postgres://user:password@db/app")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")
  envoy.set("DATABASE_STATEMENT_TIMEOUT_MS", "4000")
  envoy.set("DATABASE_LOCK_TIMEOUT_MS", "5000")
  envoy.set("DATABASE_TRANSACTION_TIMEOUT_MS", "15000")
  envoy.set("DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS", "5000")

  config.load(environment.Production)
  |> should.equal(Error(messages.database_lock_timeout_exceeded))
}

pub fn production_reads_environment_test() {
  envoy.set("APP_ENV", "production")
  envoy.set("DATABASE_URL", "postgres://user:password@db/app")
  envoy.set("DATABASE_POOL_SIZE", "20")
  envoy.set("DATABASE_QUERY_TIMEOUT_MS", "7000")
  envoy.set("DATABASE_STATEMENT_TIMEOUT_MS", "4000")
  envoy.set("DATABASE_LOCK_TIMEOUT_MS", "1000")
  envoy.set("DATABASE_TRANSACTION_TIMEOUT_MS", "15000")
  envoy.set("DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS", "5000")

  let assert Ok(postgres_config) = config.load(environment.Production)

  postgres_config.url
  |> should.equal("postgres://user:password@db/app")

  postgres_config.pool_size
  |> should.equal(20)

  postgres_config.query_timeout
  |> should.equal(7000)
  postgres_config.statement_timeout
  |> should.equal(db_defaults.statement_timeout)
  postgres_config.lock_timeout
  |> should.equal(db_defaults.lock_timeout)
  postgres_config.transaction_timeout
  |> should.equal(db_defaults.transaction_timeout)
  postgres_config.idle_in_transaction_timeout
  |> should.equal(db_defaults.idle_in_transaction_timeout)
}
