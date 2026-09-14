import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/identity_panel/identity_panel

pub fn view(user_id: String) -> Element(Message) {
  html.main([attribute.class("user-page")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/user.css"),
    ]),
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/identity_panel/identity_panel.css"),
    ]),
    html.div([attribute.class("user-page__slot")], []),
    identity_panel.view(user_id),
  ])
}
