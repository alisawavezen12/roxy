import app/message.{type Message}
import app/model.{type AuthState}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import modules/authenticated_user/authenticated_user

pub fn view(
  content: Element(Message),
  auth: AuthState,
  auth_modal_open: Bool,
  settings_modal_open: Bool,
) -> Element(Message) {
  html.div([], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/ui/layout/base_layout/base_layout.css"),
    ]),
    authenticated_user.stylesheet(),
    html.div([attribute.class("layout")], [
      html.div([attribute.class("layout__sidebar")], [
        authenticated_user.view(auth, auth_modal_open, settings_modal_open),
      ]),
      html.div([attribute.class("layout__content")], [content]),
    ]),
  ])
}
