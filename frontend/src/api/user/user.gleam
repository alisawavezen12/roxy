import gleam/dynamic/decode
import gleam/json
import shared/http_status as status
import shared/user.{type User}

import lustre/effect.{type Effect}

pub type Result {
  Found(User)
  NotFound
  Failed
}

pub fn load(id: String) -> Effect(Result) {
  effect.from(fn(dispatch) {
    load_ffi(id, fn(status, body) { dispatch(decode_response(status, body)) })
  })
}

pub fn decode_response(response_status: Int, body: String) -> Result {
  case response_status == status.ok {
    True ->
      case json.parse(body, response_decoder()) {
        Ok(user) -> Found(user)
        Error(_) -> Failed
      }
    False ->
      case response_status == status.not_found {
        True -> NotFound
        False -> Failed
      }
  }
}

fn response_decoder() -> decode.Decoder(User) {
  decode.field("user", user.decoder(), decode.success)
}

@external(javascript, "./user_ffi.mjs", "loadUser")
fn load_ffi(id: String, callback: fn(Int, String) -> Nil) -> Nil
