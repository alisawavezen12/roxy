import gleam/dynamic/decode
import gleam/option.{type Option}
import pog

pub type User {
  User(
    id: String,
    email: String,
    username: Option(String),
    first_name: Option(String),
    last_name: Option(String),
    avatar_url: Option(String),
  )
}

pub fn upsert(
  connection: pog.Connection,
  user: User,
  timeout: Int,
) -> Result(String, pog.QueryError) {
  let query =
    pog.query(
      "insert into users (id, dobrunia_user_id, email, username, first_name, last_name, avatar_url) values ($1, $1, $2, $3, $4, $5, $6) on conflict (dobrunia_user_id) do update set email = excluded.email, username = excluded.username, first_name = excluded.first_name, last_name = excluded.last_name, avatar_url = excluded.avatar_url, updated_at = now() returning id",
    )
    |> pog.parameter(pog.text(user.id))
    |> pog.parameter(pog.text(user.email))
    |> pog.parameter(pog.nullable(pog.text, user.username))
    |> pog.parameter(pog.nullable(pog.text, user.first_name))
    |> pog.parameter(pog.nullable(pog.text, user.last_name))
    |> pog.parameter(pog.nullable(pog.text, user.avatar_url))
    |> pog.returning(decode.subfield([0], decode.string, decode.success))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(rows: [user_id, ..], ..)) -> Ok(user_id)
    Ok(_) -> Error(pog.UnexpectedResultType([]))
    Error(error) -> Error(error)
  }
}
