import application/services/auth/dobrunia
import application/services/auth/session
import application/services/user as user_service
import config/auth
import gleam/option
import gleam/result
import pog
import security/token_cipher
import shared/user.{type User}

pub type Error {
  Auth(dobrunia.Error)
  Database(pog.QueryError)
  InvalidStoredToken
}

pub fn sync_profile(
  connection: pog.Connection,
  config: auth.AuthConfig,
  session_token: String,
  local_user_id: String,
  query_timeout: Int,
) -> Result(User, Error) {
  let encryption_key = encryption_key(config)
  use credentials <- result.try(
    session.provider_credentials(
      connection,
      session_token,
      False,
      query_timeout,
    )
    |> result.map_error(database_or_invalid_token),
  )
  use access_token <- result.try(decrypt(
    credentials.access_token,
    encryption_key,
  ))
  use profile <- result.try(
    dobrunia.user(access_token)
    |> result.map_error(Auth),
  )
  let persisted =
    pog.transaction(connection, fn(transaction) {
      user_service.sync_identity(
        transaction,
        local_user_id,
        profile,
        query_timeout,
      )
      |> result.map_error(Database)
    })
  case persisted {
    Ok(Nil) ->
      case user_service.find(connection, local_user_id, query_timeout) {
        Ok(option.Some(local_user)) -> Ok(local_user)
        Ok(option.None) -> Error(InvalidStoredToken)
        Error(error) -> Error(Database(error))
      }
    Error(pog.TransactionRolledBack(error)) -> Error(error)
    Error(pog.TransactionQueryError(error)) -> Error(Database(error))
  }
}

pub fn refresh_session(
  connection: pog.Connection,
  config: auth.AuthConfig,
  session_token: String,
  query_timeout: Int,
) -> Result(Nil, Error) {
  let encryption_key = encryption_key(config)
  use current <- result.try(
    session.provider_credentials(
      connection,
      session_token,
      False,
      query_timeout,
    )
    |> result.map_error(database_or_invalid_token),
  )
  use refresh_token <- result.try(decrypt(current.refresh_token, encryption_key))
  use tokens <- result.try(
    dobrunia.refresh(refresh_token)
    |> result.map_error(Auth),
  )
  let persisted =
    pog.transaction(connection, fn(transaction) {
      use locked <- result.try(
        session.provider_credentials(
          transaction,
          session_token,
          True,
          query_timeout,
        )
        |> result.map_error(database_or_invalid_token),
      )
      case locked.refresh_token == current.refresh_token {
        False -> Error(InvalidStoredToken)
        True ->
          session.update_provider_tokens(
            transaction,
            session_token,
            token_cipher.encrypt(tokens.access_token, encryption_key),
            token_cipher.encrypt(tokens.refresh_token, encryption_key),
            query_timeout,
          )
          |> result.map_error(Database)
      }
    })
  transaction_result(persisted)
}

pub fn logout_session(
  connection: pog.Connection,
  config: auth.AuthConfig,
  session_token: String,
  query_timeout: Int,
) -> Result(Nil, Error) {
  let encryption_key = encryption_key(config)
  use credentials <- result.try(
    session.provider_credentials(
      connection,
      session_token,
      False,
      query_timeout,
    )
    |> result.map_error(database_or_invalid_token),
  )
  use refresh_token <- result.try(decrypt(
    credentials.refresh_token,
    encryption_key,
  ))
  use _ <- result.try(
    dobrunia.logout(refresh_token)
    |> result.map_error(Auth),
  )
  session.revoke(connection, session_token, query_timeout)
  |> result.map_error(Database)
}

fn encryption_key(config: auth.AuthConfig) -> BitArray {
  let auth.AuthConfig(token_encryption_key:, ..) = config
  token_cipher.derive_key(token_encryption_key)
}

fn decrypt(value: BitArray, key: BitArray) -> Result(String, Error) {
  token_cipher.decrypt(value, key)
  |> result.map_error(fn(_) { InvalidStoredToken })
}

fn database_or_invalid_token(error: session.VerificationError) -> Error {
  case error {
    session.Database(error) -> Database(error)
    _ -> InvalidStoredToken
  }
}

fn transaction_result(
  value: Result(Nil, pog.TransactionError(Error)),
) -> Result(Nil, Error) {
  case value {
    Ok(Nil) -> Ok(Nil)
    Error(pog.TransactionRolledBack(error)) -> Error(error)
    Error(pog.TransactionQueryError(error)) -> Error(Database(error))
  }
}
