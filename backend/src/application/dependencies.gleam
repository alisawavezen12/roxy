import config/app
import db/pool
import exception
import pog
import ratelimit/limiter

pub type Dependencies {
  Dependencies(
    config: app.AppConfig,
    postgres: pog.Connection,
    rate_limiter: limiter.Limiter,
  )
}

pub fn new(
  config: app.AppConfig,
  postgres: pog.Connection,
  rate_limiter: limiter.Limiter,
) -> Dependencies {
  Dependencies(config:, postgres:, rate_limiter:)
}

pub fn execute_query(
  dependencies: Dependencies,
  sql: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let Dependencies(config:, postgres:, ..) = dependencies
  pool.execute(postgres, sql, config.postgres.query_timeout)
}

pub fn postgres_ready(dependencies: Dependencies) -> Bool {
  let Dependencies(config:, postgres:, ..) = dependencies
  case
    exception.rescue(fn() {
      pool.execute(postgres, "select 1", config.postgres.query_timeout)
    })
  {
    Ok(Ok(_)) -> True
    Ok(Error(_)) | Error(_) -> False
  }
}
