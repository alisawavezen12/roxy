import application/access
import gleam/bit_array
import gleam/crypto

pub type VerificationError {
  InvalidSignature
  InvalidPayload
  EmptyPrincipal
}

pub fn verify(
  signed_value: String,
  secret_key_base: String,
) -> Result(access.Principal, VerificationError) {
  case crypto.verify_signed_message(signed_value, <<secret_key_base:utf8>>) {
    Error(_) -> Error(InvalidSignature)
    Ok(value) ->
      case bit_array.to_string(value) {
        Error(_) -> Error(InvalidPayload)
        Ok(user_id) ->
          case user_id {
            "" -> Error(EmptyPrincipal)
            _ -> Ok(access.principal(user_id))
          }
      }
  }
}
