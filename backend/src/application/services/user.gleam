import gleam/dynamic/decode
import gleam/option.{type Option}
import pog

pub type Profile {
  Profile(
    id: String,
    email: String,
    first_name: Option(String),
    last_name: Option(String),
    avatar_url: Option(String),
  )
}

pub fn upsert(
  connection: pog.Connection,
  profile: Profile,
  timeout: Int,
) -> Result(String, pog.QueryError) {
  let query =
    pog.query(
      "insert into users (id, dobrunia_user_id, email, first_name, last_name, avatar_url) values ($1, $1, $2, $3, $4, $5) on conflict (dobrunia_user_id) do update set email = excluded.email, first_name = excluded.first_name, last_name = excluded.last_name, avatar_url = excluded.avatar_url, updated_at = now() returning id",
    )
    |> pog.parameter(pog.text(profile.id))
    |> pog.parameter(pog.text(profile.email))
    |> pog.parameter(pog.nullable(pog.text, profile.first_name))
    |> pog.parameter(pog.nullable(pog.text, profile.last_name))
    |> pog.parameter(pog.nullable(pog.text, profile.avatar_url))
    |> pog.returning(decode.subfield([0], decode.string, decode.success))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(rows: [user_id, ..], ..)) -> Ok(user_id)
    Ok(_) -> Error(pog.UnexpectedResultType([]))
    Error(error) -> Error(error)
  }
}
