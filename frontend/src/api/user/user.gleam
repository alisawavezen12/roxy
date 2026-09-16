import gleam/dynamic/decode
import gleam/json
import shared/api/error as api_error
import shared/http_status as status
import shared/user.{type User}

import lustre/effect.{type Effect}

pub type Result {
  Found(User)
  NotFound
  Failed
}

pub type SaveBioResult {
  BioSaved(User)
  BioSaveFailed(String)
}

pub fn load(id: String) -> Effect(Result) {
  effect.from(fn(dispatch) {
    load_ffi(id, fn(status, body) { dispatch(decode_response(status, body)) })
  })
}

pub fn save_bio(bio: String) -> Effect(SaveBioResult) {
  effect.from(fn(dispatch) {
    save_bio_ffi(bio, fn(status, body) {
      dispatch(decode_save_bio(status, body))
    })
  })
}

pub fn decode_save_bio(response_status: Int, body: String) -> SaveBioResult {
  case response_status == status.ok {
    True ->
      case json.parse(body, response_decoder()) {
        Ok(user) -> BioSaved(user)
        Error(_) -> BioSaveFailed("Unable to save bio. Please try again.")
      }
    False -> decode_save_bio_error(body)
  }
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

fn decode_save_bio_error(body: String) -> SaveBioResult {
  case json.parse(body, api_error.decoder()) {
    Ok(api_error.ApiError(code: "bio_too_long", message:, ..)) ->
      BioSaveFailed(message)
    _ -> BioSaveFailed("Unable to save bio. Please try again.")
  }
}

fn response_decoder() -> decode.Decoder(User) {
  decode.field("user", user.decoder(), decode.success)
}

@external(javascript, "./user_ffi.mjs", "loadUser")
fn load_ffi(id: String, callback: fn(Int, String) -> Nil) -> Nil

@external(javascript, "./user_ffi.mjs", "saveBio")
fn save_bio_ffi(bio: String, callback: fn(Int, String) -> Nil) -> Nil
