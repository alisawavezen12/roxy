import db/config
import db/pool
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/order
import gleam/result
import gleam/string
import pog
import simplifile

const migration_directory = "migrations"

pub type Error {
  Directory(String)
  InvalidFilename(String)
  Read(String)
  Database(String)
}

pub type Migration {
  Migration(version: String, filename: String, sql: String)
}

pub fn ensure_directory(directory: String) -> Result(Nil, Error) {
  case simplifile.is_directory(directory) {
    Ok(True) -> Ok(Nil)
    Ok(False) ->
      simplifile.create_directory_all(directory)
      |> result.map_error(fn(_) { Directory(directory) })
    Error(_) -> Error(Directory(directory))
  }
}

pub fn run(
  postgres: pog.Connection,
  config: config.PostgresConfig,
) -> Result(Nil, Error) {
  run_from_directory(postgres, config, migration_directory)
}

pub fn run_from_directory(
  postgres: pog.Connection,
  config: config.PostgresConfig,
  directory: String,
) -> Result(Nil, Error) {
  use migrations <- result.try(load_migrations(directory))
  use _ <- result.try(ensure_schema_migrations(postgres, config.query_timeout))
  use _ <- result.try(apply_pending(postgres, config.query_timeout, migrations))
  Ok(Nil)
}

pub fn load_migrations(directory: String) -> Result(List(Migration), Error) {
  use _ <- result.try(ensure_directory(directory))
  use filenames <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(fn(_) { Directory(directory) }),
  )
  use migrations <- result.try(load_migration_files(directory, filenames, []))
  Ok(list.sort(migrations, by: compare_migrations))
}

fn load_migration_files(
  directory: String,
  filenames: List(String),
  migrations: List(Migration),
) -> Result(List(Migration), Error) {
  case filenames {
    [] -> Ok(migrations)
    [filename, ..rest] ->
      case parse_filename(directory, filename) {
        Ok(option.None) -> load_migration_files(directory, rest, migrations)
        Ok(option.Some(migration)) ->
          load_migration_files(directory, rest, [migration, ..migrations])
        Error(error) -> Error(error)
      }
  }
}

fn parse_filename(
  directory: String,
  filename: String,
) -> Result(Option(Migration), Error) {
  case string.split(filename, ".") {
    [version, "sql"] ->
      case valid_version(version) {
        False -> Error(InvalidFilename(filename))
        True -> {
          let path = directory <> "/" <> filename
          case simplifile.read(path) {
            Ok(sql) -> Ok(option.Some(Migration(version:, filename:, sql:)))
            Error(_) -> Error(Read(path))
          }
        }
      }
    _ -> Ok(option.None)
  }
}

fn valid_version(version: String) -> Bool {
  case string.split(version, "_") {
    [prefix, ..] ->
      case int.parse(prefix) {
        Ok(_) -> True
        Error(_) -> False
      }
    [] -> False
  }
}

fn compare_migrations(left: Migration, right: Migration) -> order.Order {
  string.compare(left.version, right.version)
}

fn ensure_schema_migrations(
  postgres: pog.Connection,
  timeout: Int,
) -> Result(Nil, Error) {
  case
    pool.execute(
      postgres,
      "create table if not exists schema_migrations (version text primary key, applied_at timestamptz not null default now())",
      timeout,
    )
  {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(Database(query_error(error)))
  }
}

fn apply_pending(
  postgres: pog.Connection,
  timeout: Int,
  migrations: List(Migration),
) -> Result(Nil, Error) {
  case migrations {
    [] -> Ok(Nil)
    [migration, ..rest] ->
      case applied(postgres, timeout, migration.version) {
        Error(error) -> Error(error)
        Ok(True) -> apply_pending(postgres, timeout, rest)
        Ok(False) -> {
          let result =
            pog.transaction(postgres, fn(connection) {
              case pool.execute(connection, migration.sql, timeout) {
                Ok(_) ->
                  case
                    pool.execute(
                      connection,
                      insert_sql(migration.version),
                      timeout,
                    )
                  {
                    Ok(_) -> Ok(Nil)
                    Error(error) -> Error(query_error(error))
                  }
                Error(error) -> Error(query_error(error))
              }
            })
          case result {
            Ok(_) -> apply_pending(postgres, timeout, rest)
            Error(error) -> Error(Database(transaction_error(error)))
          }
        }
      }
  }
}

fn applied(
  postgres: pog.Connection,
  timeout: Int,
  version: String,
) -> Result(Bool, Error) {
  let query =
    pog.query("select version from schema_migrations where version = $1")
    |> pog.parameter(pog.text(version))
    |> pog.returning(decode.string)
    |> pog.timeout(timeout)
  case pog.execute(query, postgres) {
    Ok(result) -> Ok(result.rows != [])
    Error(error) -> Error(Database(query_error(error)))
  }
}

fn insert_sql(version: String) -> String {
  "insert into schema_migrations (version) values ('" <> escape(version) <> "')"
}

fn escape(value: String) -> String {
  value |> string.replace("'", "''")
}

fn query_error(error: pog.QueryError) -> String {
  case error {
    pog.ConstraintViolated(message:, ..) -> message
    pog.PostgresqlError(message:, ..) -> message
    pog.UnexpectedArgumentCount(..) -> "Unexpected argument count"
    pog.UnexpectedArgumentType(..) -> "Unexpected argument type"
    pog.UnexpectedResultType(_) -> "Unexpected result type"
    pog.QueryTimeout -> "Query timeout"
    pog.ConnectionUnavailable -> "Connection unavailable"
  }
}

fn transaction_error(error: pog.TransactionError(String)) -> String {
  case error {
    pog.TransactionQueryError(error) -> query_error(error)
    pog.TransactionRolledBack(error) -> error
  }
}
