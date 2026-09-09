import config/app
import db/pool
import pog

pub type Dependencies {
  Dependencies(config: app.AppConfig, postgres: pog.Connection)
}

pub fn new(config: app.AppConfig, postgres: pog.Connection) -> Dependencies {
  Dependencies(config:, postgres:)
}

pub fn execute_query(
  dependencies: Dependencies,
  sql: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let Dependencies(config:, postgres:) = dependencies
  pool.execute(postgres, sql, config.postgres.query_timeout)
}
