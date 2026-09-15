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

pub type ProviderCredentials {
  ProviderCredentials(
    access_token: BitArray,
    refresh_token: BitArray,
    provider_session_id: String,
  )
}

pub fn create(
  connection: pog.Connection,
  user_id: String,
  ttl_seconds: Int,
  timeout: Int,
) -> Result(String, pog.QueryError) {
  create_with_permissions(connection, user_id, [], ttl_seconds, timeout)
}

pub fn create_with_permissions(
  connection: pog.Connection,
  user_id: String,
  permissions: List(String),
  ttl_seconds: Int,
  timeout: Int,
) -> Result(String, pog.QueryError) {
  let token =
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  let expires_at = now_seconds() + ttl_seconds
  let query =
    pog.query(
      "insert into sessions (token_hash, user_id, permissions, expires_at, revoked) values ($1, $2, $3, to_timestamp($4::double precision), false)",
    )
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.parameter(pog.text(user_id))
    |> pog.parameter(pog.array(pog.text, permissions))
    |> pog.parameter(pog.int(expires_at))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(_) -> Ok(token)
    Error(error) -> Error(error)
  }
}

pub fn create_with_provider(
  connection: pog.Connection,
  user_id: String,
  provider_session_id: String,
  encrypted_access_token: BitArray,
  encrypted_refresh_token: BitArray,
  ttl_seconds: Int,
  timeout: Int,
) -> Result(String, pog.QueryError) {
  let token =
    crypto.strong_random_bytes(32)
    |> bit_array.base64_url_encode(False)
  let expires_at = now_seconds() + ttl_seconds
  let query =
    pog.query(
      "insert into sessions (token_hash, user_id, permissions, expires_at, revoked, provider_session_id, provider_access_token, provider_refresh_token) values ($1, $2, '{}', to_timestamp($3::double precision), false, $4, $5, $6)",
    )
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.parameter(pog.text(user_id))
    |> pog.parameter(pog.int(expires_at))
    |> pog.parameter(pog.text(provider_session_id))
    |> pog.parameter(pog.bytea(encrypted_access_token))
    |> pog.parameter(pog.bytea(encrypted_refresh_token))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(_) -> Ok(token)
    Error(error) -> Error(error)
  }
}

pub fn provider_credentials(
  connection: pog.Connection,
  token: String,
  for_update: Bool,
  timeout: Int,
) -> Result(ProviderCredentials, VerificationError) {
  let locking = case for_update {
    True -> " for update"
    False -> ""
  }
  let query =
    pog.query(
      "select provider_access_token, provider_refresh_token, provider_session_id from sessions where token_hash = $1 and revoked = false and expires_at > now() and provider_access_token is not null and provider_refresh_token is not null and provider_session_id is not null"
      <> locking,
    )
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.returning(provider_credentials_decoder())
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Error(error) -> Error(Database(error))
    Ok(pog.Returned(rows: [credentials, ..], ..)) -> Ok(credentials)
    Ok(_) -> Error(InvalidToken)
  }
}

pub fn update_provider_tokens(
  connection: pog.Connection,
  token: String,
  encrypted_access_token: BitArray,
  encrypted_refresh_token: BitArray,
  timeout: Int,
) -> Result(Nil, pog.QueryError) {
  let query =
    pog.query(
      "update sessions set provider_access_token = $2, provider_refresh_token = $3 where token_hash = $1 and revoked = false and expires_at > now()",
    )
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.parameter(pog.bytea(encrypted_access_token))
    |> pog.parameter(pog.bytea(encrypted_refresh_token))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(count: 1, ..)) -> Ok(Nil)
    Ok(_) -> Error(pog.UnexpectedResultType([]))
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
      "select user_id, permissions, extract(epoch from expires_at)::bigint, revoked from sessions where token_hash = $1",
    )
    |> pog.parameter(pog.bytea(token_hash(token)))
    |> pog.returning(session_decoder())
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Error(error) -> Error(Database(error))
    Ok(result) ->
      case result.rows {
        [] -> Error(InvalidToken)
        [#(user_id, permissions, expires_at, revoked), ..] -> {
          let expired = expires_at <= now_seconds()
          case revoked, expired {
            True, _ -> Error(Revoked)
            False, True -> Error(Expired)
            False, False ->
              Ok(access.principal_with_permissions(user_id, permissions))
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

fn provider_credentials_decoder() -> decode.Decoder(ProviderCredentials) {
  decode.subfield([0], decode.bit_array, fn(access_token) {
    decode.subfield([1], decode.bit_array, fn(refresh_token) {
      decode.subfield([2], decode.string, fn(provider_session_id) {
        decode.success(ProviderCredentials(
          access_token:,
          refresh_token:,
          provider_session_id:,
        ))
      })
    })
  })
}

fn session_decoder() -> decode.Decoder(#(String, List(String), Int, Bool)) {
  decode.subfield([0], decode.string, fn(user_id) {
    decode.subfield([1], decode.list(decode.string), fn(permissions) {
      decode.subfield([2], decode.int, fn(expires_at) {
        decode.subfield([3], decode.bool, fn(revoked) {
          decode.success(#(user_id, permissions, expires_at, revoked))
        })
      })
    })
  })
}
