import app/message.{type Message}
import gleam/option
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
    ..bio(profile)
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
