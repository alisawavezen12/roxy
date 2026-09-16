import app/message.{type Message}
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import shared/user.{type User}

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href("/pages/user/identity_panel/identity_panel.css"),
  ])
}

pub fn view(profile: User) -> Element(Message) {
  html.aside([attribute.class("identity-panel")], [
    avatar(profile),
    html.h2([], [html.text(user.display_name(profile))]),
    html.p([attribute.class("identity-panel__handle")], [
      html.text(handle(profile)),
    ]),
    ..metadata(profile)
  ])
}

pub fn avatar(profile: User) -> Element(message) {
  case profile.avatar_url {
    option.Some(url) if url != "" ->
      html.img([
        attribute.class("identity-panel__avatar"),
        attribute.src(url),
        attribute.alt(user.display_name(profile) <> " avatar"),
      ])
    _ ->
      html.div(
        [
          attribute.class("identity-panel__avatar"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [html.text(user.avatar_letter(profile))],
      )
  }
}

fn metadata(profile: User) -> List(Element(Message)) {
  list.append(joined(profile), bio(profile))
}

fn joined(profile: User) -> List(Element(Message)) {
  case profile.created_at {
    option.Some(value) -> [
      html.p([attribute.class("identity-panel__joined")], [
        html.text("Joined " <> joined_month(value)),
      ]),
    ]
    option.None -> []
  }
}

fn joined_month(value: String) -> String {
  case string.split(value, "-") {
    [year, month, ..] -> month_name(month) <> " " <> year
    _ -> value
  }
}

fn month_name(value: String) -> String {
  case value {
    "01" -> "Jan"
    "02" -> "Feb"
    "03" -> "Mar"
    "04" -> "Apr"
    "05" -> "May"
    "06" -> "Jun"
    "07" -> "Jul"
    "08" -> "Aug"
    "09" -> "Sep"
    "10" -> "Oct"
    "11" -> "Nov"
    "12" -> "Dec"
    _ -> value
  }
}

fn bio(profile: User) -> List(Element(Message)) {
  case profile.bio {
    option.Some(bio) if bio != "" -> [
      html.p([attribute.class("identity-panel__bio")], [html.text(bio)]),
    ]
    _ -> []
  }
}

fn handle(profile: User) -> String {
  case profile.username {
    option.Some(username) if username != "" -> "@" <> username
    _ -> profile.email
  }
}
