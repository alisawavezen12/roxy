import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

pub type User {
  User(
    id: String,
    email: String,
    username: Option(String),
    first_name: Option(String),
    last_name: Option(String),
    avatar_url: Option(String),
    bio: Option(String),
    created_at: Option(String),
    updated_at: Option(String),
  )
}

pub fn decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.string)
  use email <- decode.field("email", decode.string)
  use username <- decode.optional_field(
    "username",
    option.None,
    decode.optional(decode.string),
  )
  use first_name <- decode.optional_field(
    "firstName",
    option.None,
    decode.optional(decode.string),
  )
  use last_name <- decode.optional_field(
    "lastName",
    option.None,
    decode.optional(decode.string),
  )
  use avatar_url <- decode.optional_field(
    "avatarUrl",
    option.None,
    decode.optional(decode.string),
  )
  use bio <- decode.optional_field(
    "bio",
    option.None,
    decode.optional(decode.string),
  )
  use created_at <- decode.optional_field(
    "createdAt",
    option.None,
    decode.optional(decode.string),
  )
  use updated_at <- decode.optional_field(
    "updatedAt",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(User(
    id:,
    email:,
    username:,
    first_name:,
    last_name:,
    avatar_url:,
    bio:,
    created_at:,
    updated_at:,
  ))
}

pub fn encode(user: User) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #("email", json.string(user.email)),
    #("username", encode_optional(user.username)),
    #("firstName", encode_optional(user.first_name)),
    #("lastName", encode_optional(user.last_name)),
    #("avatarUrl", encode_optional(user.avatar_url)),
    #("bio", encode_optional(user.bio)),
    #("createdAt", encode_optional(user.created_at)),
    #("updatedAt", encode_optional(user.updated_at)),
  ])
}

pub fn display_name(user: User) -> String {
  let full_name =
    [user.first_name, user.last_name]
    |> list.filter_map(option.to_result(_, Nil))
    |> string.join(" ")
  case full_name, user.username {
    "", option.Some(username) if username != "" -> username
    "", _ -> user.email
    name, _ -> name
  }
}

pub fn avatar_letter(user: User) -> String {
  let value = case user.username {
    option.Some(username) if username != "" -> username
    _ -> user.email
  }
  value
  |> string.first
  |> result.unwrap("?")
  |> string.uppercase
}

fn encode_optional(value: Option(String)) -> json.Json {
  case value {
    option.Some(value) -> json.string(value)
    option.None -> json.null()
  }
}
