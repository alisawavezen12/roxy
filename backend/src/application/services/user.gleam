import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/string
import pog
import shared/user.{type User, User}

pub fn find(
  connection: pog.Connection,
  id: String,
  timeout: Int,
) -> Result(Option(User), pog.QueryError) {
  let query =
    pog.query(
      "select id, email, username, first_name, last_name, avatar_url, bio, to_char(created_at, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'), to_char(updated_at, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') from users where id = $1",
    )
    |> pog.parameter(pog.text(id))
    |> pog.returning(user_decoder())
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(rows: [user, ..], ..)) -> Ok(option.Some(user))
    Ok(_) -> Ok(option.None)
    Error(error) -> Error(error)
  }
}

pub fn update_bio(
  connection: pog.Connection,
  local_user_id: String,
  bio: String,
  timeout: Int,
) -> Result(Nil, pog.QueryError) {
  let bio = case string.trim(bio) {
    "" -> option.None
    value -> option.Some(value)
  }
  let query =
    pog.query("update users set bio = $2, updated_at = now() where id = $1")
    |> pog.parameter(pog.text(local_user_id))
    |> pog.parameter(pog.nullable(pog.text, bio))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(count: 1, ..)) -> Ok(Nil)
    Ok(_) -> Error(pog.UnexpectedResultType([]))
    Error(error) -> Error(error)
  }
}

pub fn sync_identity(
  connection: pog.Connection,
  local_user_id: String,
  user: User,
  timeout: Int,
) -> Result(Nil, pog.QueryError) {
  let query =
    pog.query(
      "update users set email = $3, username = $4, first_name = $5, last_name = $6, avatar_url = $7, updated_at = now() where id = $1 and dobrunia_user_id = $2",
    )
    |> pog.parameter(pog.text(local_user_id))
    |> pog.parameter(pog.text(user.id))
    |> pog.parameter(pog.text(user.email))
    |> pog.parameter(pog.nullable(pog.text, user.username))
    |> pog.parameter(pog.nullable(pog.text, user.first_name))
    |> pog.parameter(pog.nullable(pog.text, user.last_name))
    |> pog.parameter(pog.nullable(pog.text, user.avatar_url))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(count: 1, ..)) -> Ok(Nil)
    Ok(_) -> Error(pog.UnexpectedResultType([]))
    Error(error) -> Error(error)
  }
}

pub fn upsert_identity(
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

fn user_decoder() -> decode.Decoder(User) {
  decode.subfield([0], decode.string, fn(id) {
    decode.subfield([1], decode.string, fn(email) {
      decode.subfield([2], decode.optional(decode.string), fn(username) {
        decode.subfield([3], decode.optional(decode.string), fn(first_name) {
          decode.subfield([4], decode.optional(decode.string), fn(last_name) {
            decode.subfield([5], decode.optional(decode.string), fn(avatar_url) {
              decode.subfield([6], decode.optional(decode.string), fn(bio) {
                decode.subfield(
                  [7],
                  decode.optional(decode.string),
                  fn(created_at) {
                    decode.subfield(
                      [8],
                      decode.optional(decode.string),
                      fn(updated_at) {
                        decode.success(User(
                          id:,
                          email:,
                          username:,
                          first_name:,
                          last_name:,
                          avatar_url:,
                          bio:,
                          created_at:,
                          updated_at:,
                        ))
                      },
                    )
                  },
                )
              })
            })
          })
        })
      })
    })
  })
}
