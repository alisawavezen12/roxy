import gleam/option
import gleeunit/should
import shared/user.{type User, User}

pub fn display_name_prefers_full_name_test() {
  make_user(
    "person@example.com",
    option.Some("sentry"),
    option.Some("Maya"),
    option.Some("Chen"),
  )
  |> user.display_name
  |> should.equal("Maya Chen")
}

pub fn display_name_falls_back_to_username_then_email_test() {
  make_user(
    "person@example.com",
    option.Some("sentry"),
    option.None,
    option.None,
  )
  |> user.display_name
  |> should.equal("sentry")

  make_user("person@example.com", option.None, option.None, option.None)
  |> user.display_name
  |> should.equal("person@example.com")
}

pub fn avatar_letter_prefers_username_then_email_test() {
  make_user(
    "person@example.com",
    option.Some("sentry"),
    option.None,
    option.None,
  )
  |> user.avatar_letter
  |> should.equal("S")

  make_user("example@example.com", option.None, option.None, option.None)
  |> user.avatar_letter
  |> should.equal("E")
}

fn make_user(
  email: String,
  username: option.Option(String),
  first_name: option.Option(String),
  last_name: option.Option(String),
) -> User {
  User(
    id: "user-1",
    email:,
    username:,
    first_name:,
    last_name:,
    avatar_url: option.None,
    bio: option.None,
    created_at: option.None,
    updated_at: option.None,
  )
}
