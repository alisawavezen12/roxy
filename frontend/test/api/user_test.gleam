import api/auth/auth
import api/user/user
import gleam/option
import gleeunit/should
import shared/http_status as status

const body = "{\"user\":{\"id\":\"user-1\",\"email\":\"person@example.com\",\"username\":\"sentry\",\"firstName\":null,\"lastName\":null,\"avatarUrl\":\"https://cdn.example/avatar.png\",\"bio\":\"Building things\"}}"

pub fn current_user_decodes_full_profile_test() {
  let assert auth.SignedIn(current_user) = auth.decode_current_user(status.ok, body)

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

pub fn public_user_maps_found_and_not_found_test() {
  let assert user.Found(profile) = user.decode_response(status.ok, body)
  profile.email |> should.equal("person@example.com")

  user.decode_response(status.not_found, "")
  |> should.equal(user.NotFound)
}
