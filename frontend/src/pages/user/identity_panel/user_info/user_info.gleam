import app/message.{type Message}
import app/model.{
  type UserPageState, UserLoadFailed, UserLoaded, UserLoading, UserNotFound,
}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/identity_panel/identity_panel

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href("/pages/user/identity_panel/user_info/user_info.css"),
  ])
}

pub fn view(state: UserPageState) -> Element(Message) {
  html.div([attribute.class("user-info")], content(state))
}

fn content(state: UserPageState) -> List(Element(Message)) {
  case state {
    UserLoading -> [status("Loading user…")]
    UserLoaded(user) -> [
      html.div([attribute.class("user-info__content")], [
        identity_panel.view(user),
      ]),
    ]
    UserNotFound -> [empty_state()]
    UserLoadFailed -> [status("Unable to load this user.")]
  }
}

fn empty_state() -> Element(Message) {
  html.div([attribute.class("user-info__empty")], [
    html.span(
      [
        attribute.class("user-info__empty-icon"),
        attribute.attribute("aria-hidden", "true"),
      ],
      [],
    ),
    html.p([], [html.text("This user does not exist.")]),
  ])
}

fn status(message: String) -> Element(Message) {
  html.p([attribute.class("user-info__status")], [html.text(message)])
}
