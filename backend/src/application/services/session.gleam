import application/access
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode

import gleam/time/timestamp
import pog

pub type VerificationError {
  InvalidToken
  Expired
  Revoked
  Database(pog.QueryError)
}

pub fn create(
  connection: pog.Connection,
  user_id: String,
  ttl_seconds: Int,
  timeout: Int,
) -> Result(String, pog.QueryError) {
  let token =
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  let expires_at = now_seconds() + ttl_seconds
  let query =
    pog.query(
      "insert into sessions (token_hash, user_id, expires_at, revoked) values ($1, $2, to_timestamp($3::double precision), false)",
    )
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.parameter(pog.text(user_id))
    |> pog.parameter(pog.int(expires_at))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(_) -> Ok(token)
    Error(error) -> Error(error)
  }
}

pub fn verify(
  connection: pog.Connection,
  token: String,
  timeout: Int,
) -> Result(access.Principal, VerificationError) {
  let query =
    pog.query(
      "select user_id, extract(epoch from expires_at)::bigint, revoked from sessions where token_hash = $1",
    )
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.returning(session_decoder())
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Error(error) -> Error(Database(error))
    Ok(result) ->
      case result.rows {
        [] -> Error(InvalidToken)
        [#(user_id, expires_at, revoked), ..] -> {
          let expired = expires_at <= now_seconds()
          case revoked, expired {
            True, _ -> Error(Revoked)
            False, True -> Error(Expired)
            False, False -> Ok(access.principal(user_id))
          }
        }
      }
  }
}

pub fn revoke(
  connection: pog.Connection,
  token: String,
  timeout: Int,
) -> Result(Nil, pog.QueryError) {
  let query =
    pog.query("update sessions set revoked = true where token_hash = $1")
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

pub fn token_hash(token: String) -> BitArray {
  crypto.hash(crypto.Sha256, <<token:utf8>>)
}

pub fn now_seconds() -> Int {
  let current = timestamp.system_time()
  let #(seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(current)
  seconds
}

fn session_decoder() -> decode.Decoder(#(String, Int, Bool)) {
  decode.subfield([0], decode.string, fn(user_id) {
    decode.subfield([1], decode.int, fn(expires_at) {
      decode.subfield([2], decode.bool, fn(revoked) {
        decode.success(#(user_id, expires_at, revoked))
      })
    })
  })
}
