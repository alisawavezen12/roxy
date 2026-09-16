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

pub type LogoutResult {
  LoggedOut
  LogoutFailed
}

pub fn load_current_user() -> Effect(CurrentUserResult) {
  effect.from(fn(dispatch) {
    load_current_user_ffi(fn(status, body) {
      dispatch(decode_current_user(status, body))
    })
  })
}

pub fn sync_profile() -> Effect(CurrentUserResult) {
  effect.from(fn(dispatch) {
    sync_profile_ffi(fn(status, body) {
      dispatch(decode_current_user(status, body))
    })
  })
}

pub fn logout() -> Effect(LogoutResult) {
  effect.from(fn(dispatch) {
    logout_ffi(fn(status) { dispatch(decode_logout(status)) })
  })
}

pub fn start_sso_login() -> Effect(message) {
  effect.from(fn(_) { start_sso_login_ffi() })
}

pub fn decode_logout(response_status: Int) -> LogoutResult {
  case response_status == status.no_content {
    True -> LoggedOut
    False -> LogoutFailed
  }
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

@external(javascript, "./auth_ffi.mjs", "syncProfile")
fn sync_profile_ffi(callback: fn(Int, String) -> Nil) -> Nil

@external(javascript, "./auth_ffi.mjs", "logout")
fn logout_ffi(callback: fn(Int) -> Nil) -> Nil

@external(javascript, "./auth_ffi.mjs", "alertUser")
fn alert_user_ffi(message: String) -> Nil

pub fn alert_user(message: String) -> Effect(message) {
  effect.from(fn(_) { alert_user_ffi(message) })
}
