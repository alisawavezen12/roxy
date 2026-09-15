import gleam/dynamic/decode
import gleam/json
import shared/http_status as status
import shared/user.{type User}

import lustre/effect.{type Effect}

pub type CurrentUserResult {
  SignedIn(User)
  SignedOut
  Failed
}

pub fn load_current_user() -> Effect(CurrentUserResult) {
  effect.from(fn(dispatch) {
    load_current_user_ffi(fn(status, body) {
      dispatch(decode_current_user(status, body))
    })
  })
}

pub fn start_sso_login() -> Effect(message) {
  effect.from(fn(_) { start_sso_login_ffi() })
}

pub fn decode_current_user(
  response_status: Int,
  body: String,
) -> CurrentUserResult {
  case response_status == status.ok {
    True ->
      case json.parse(body, response_decoder()) {
        Ok(user) -> SignedIn(user)
        Error(_) -> Failed
      }
    False ->
      case response_status == status.unauthorized {
        True -> SignedOut
        False -> Failed
      }
  }
}

fn response_decoder() -> decode.Decoder(User) {
  decode.field("user", user.decoder(), decode.success)
}

@external(javascript, "./auth_ffi.mjs", "loadCurrentUser")
fn load_current_user_ffi(callback: fn(Int, String) -> Nil) -> Nil

@external(javascript, "./auth_ffi.mjs", "startSsoLogin")
fn start_sso_login_ffi() -> Nil
