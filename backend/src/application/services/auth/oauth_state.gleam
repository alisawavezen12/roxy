import application/services/auth/session
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import pog

pub fn create(
  connection: pog.Connection,
  ttl_seconds: Int,
  return_path: String,
  timeout: Int,
) -> Result(#(String, String), pog.QueryError) {
  let state = random_token()
  let binding = random_token()
  let expires_at = session.now_seconds() + ttl_seconds
  let query =
    pog.query(
      "insert into oauth_states (state_hash, binding_hash, expires_at, return_path) values ($1, $2, to_timestamp($3::double precision), $4)",
    )
    |> pog.parameter(pog.bytea(session.token_hash(state)))
    |> pog.parameter(pog.bytea(session.token_hash(binding)))
    |> pog.parameter(pog.int(expires_at))
    |> pog.parameter(pog.text(return_path))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(_) -> Ok(#(state, binding))
    Error(error) -> Error(error)
  }
}

pub fn consume(
  connection: pog.Connection,
  state: String,
  binding: String,
  timeout: Int,
) -> Result(ReturnTo, pog.QueryError) {
  let query =
    pog.query(
      "delete from oauth_states where state_hash = $1 and binding_hash = $2 and expires_at > now() returning return_path",
    )
    |> pog.parameter(pog.bytea(session.token_hash(state)))
    |> pog.parameter(pog.bytea(session.token_hash(binding)))
    |> pog.returning(decode.subfield([0], decode.string, decode.success))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(rows: [return_path, ..], ..)) -> Ok(ReturnTo(return_path))
    Ok(_) -> Ok(NotFound)
    Error(error) -> Error(error)
  }
}

pub type ReturnTo {
  ReturnTo(String)
  NotFound
}

fn random_token() -> String {
  crypto.strong_random_bytes(32)
  |> bit_array.base64_url_encode(False)
}
