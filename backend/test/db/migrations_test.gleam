import db/migrations
import gleeunit/should
import simplifile

pub fn empty_migrations_directory_is_valid_test() {
  let directory = "test_tmp_migrations_empty"
  let assert Ok(Nil) = migrations.ensure_directory(directory)

  migrations.load_migrations(directory)
  |> should.equal(Ok([]))

  let _ = simplifile.delete(directory)
}

pub fn migration_names_are_sorted_and_read_test() {
  let directory = "test_tmp_migrations_sorted"
  let assert Ok(Nil) = migrations.ensure_directory(directory)
  let assert Ok(Nil) =
    simplifile.write(directory <> "/0002_second.sql", "select 2;")
  let assert Ok(Nil) =
    simplifile.write(directory <> "/0001_first.sql", "select 1;")

  let assert Ok([first, second]) = migrations.load_migrations(directory)
  first.version
  |> should.equal("0001_first")
  second.version
  |> should.equal("0002_second")

  let _ = simplifile.delete(directory)
}

pub fn migration_file_can_contain_multiple_statements_test() {
  let directory = "test_tmp_migrations_multiple_statements"
  let assert Ok(Nil) = migrations.ensure_directory(directory)
  let sql = "create table first ();\ncreate table second ();"
  let assert Ok(Nil) = simplifile.write(directory <> "/0001_tables.sql", sql)

  let assert Ok([migration]) = migrations.load_migrations(directory)
  migration.sql |> should.equal(sql)

  let _ = simplifile.delete(directory)
}

pub fn invalid_migration_filename_is_rejected_test() {
  let directory = "test_tmp_migrations_invalid"
  let assert Ok(Nil) = migrations.ensure_directory(directory)
  let assert Ok(Nil) =
    simplifile.write(directory <> "/migration.sql", "select 1;")

  migrations.load_migrations(directory)
  |> should.equal(Error(migrations.InvalidFilename("migration.sql")))

  let _ = simplifile.delete(directory)
}
