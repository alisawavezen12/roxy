import api/auth/auth
import api/user/user
import gleam/option
import gleeunit/should
import shared/http_status as status

const body = "{\"user\":{\"id\":\"user-1\",\"email\":\"person@example.com\",\"username\":\"sentry\",\"firstName\":null,\"lastName\":null,\"avatarUrl\":\"https://cdn.example/avatar.png\",\"bio\":\"Building things\"}}"

pub fn current_user_decodes_full_profile_test() {
  let assert auth.SignedIn(current_user) =
    auth.decode_current_user(status.ok, body)

  current_user.id |> should.equal("user-1")
  current_user.username |> should.equal(option.Some("sentry"))
  current_user.avatar_url
  |> should.equal(option.Some("https://cdn.example/avatar.png"))
  current_user.bio |> should.equal(option.Some("Building things"))
}

pub fn current_user_maps_unauthorized_test() {
  auth.decode_current_user(status.unauthorized, "")
  |> should.equal(auth.SignedOut)
}

pub fn save_bio_decodes_updated_profile_test() {
  let assert user.BioSaved(profile) = user.decode_save_bio(status.ok, body)

  profile.bio |> should.equal(option.Some("Building things"))
}

pub fn save_bio_decodes_shared_length_error_test() {
  let body =
    "{\"error\":{\"code\":\"bio_too_long\",\"message\":\"Bio must be 300 characters or fewer.\",\"request_id\":\"req_test\"}}"

  user.decode_save_bio(status.bad_request, body)
  |> should.equal(user.BioSaveFailed("Bio must be 300 characters or fewer."))
}

pub fn save_bio_maps_failure_status_to_failure_test() {
  user.decode_save_bio(status.internal_server_error, "")
  |> should.equal(user.BioSaveFailed("Unable to save bio. Please try again."))
}

pub fn logout_maps_no_content_to_success_test() {
  auth.decode_logout(status.no_content)
  |> should.equal(auth.LoggedOut)
}

pub fn logout_maps_other_status_to_failure_test() {
  auth.decode_logout(status.internal_server_error)
  |> should.equal(auth.LogoutFailed)
}

pub fn public_user_maps_found_and_not_found_test() {
  let assert user.Found(profile) = user.decode_response(status.ok, body)
  profile.email |> should.equal("person@example.com")

  user.decode_response(status.not_found, "")
  |> should.equal(user.NotFound)
}
