import app/message.{type Message, CloseAuthModal, StartSsoLogin}
import app/model.{
  type AuthState, Authenticated, Checking, Unauthenticated, Unavailable,
}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/identity_panel/identity_panel
import ui/components/button/button
import ui/components/modal/modal

pub fn view(
  user_id: String,
  auth: AuthState,
  auth_modal_open: Bool,
) -> Element(Message) {
  let modal_views = case auth_modal_open {
    True -> [auth_modal(auth)]
    False -> []
  }
  html.main([attribute.class("user-page")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/user.css"),
    ]),
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/identity_panel/identity_panel.css"),
    ]),
    button.stylesheet(),
    modal.stylesheet(),
    html.div([attribute.class("user-page__slot")], left_content(auth)),
    identity_panel.view(user_id),
    ..modal_views
  ])
}

fn left_content(auth: AuthState) -> List(Element(Message)) {
  case auth {
    Authenticated(name) -> [
      html.section([attribute.class("user-page__current-user")], [
        html.p([attribute.class("user-page__eyebrow")], [
          html.text("Signed in as"),
        ]),
        html.p([attribute.class("user-page__current-user-name")], [
          html.text(name),
        ]),
      ]),
    ]
    Checking -> [
      html.p([attribute.class("user-page__auth-status")], [
        html.text("Checking session…"),
      ]),
    ]
    Unauthenticated | Unavailable -> []
  }
}

fn auth_modal(auth: AuthState) -> Element(Message) {
  let message = case auth {
    Unavailable -> "Unable to check the session. Please try again."
    _ -> "Sign in with Dobrunia to continue using Roxy."
  }
  modal.view(
    modal.Config(
      title: "Sign in to Roxy",
      close_label: "Close sign-in dialog",
      on_close: CloseAuthModal,
      children: [
        html.p([attribute.class("user-page__auth-copy")], [html.text(message)]),
        button.view(button.Config(
          label: "Sign in with Dobrunia",
          size: button.Large,
          variant: button.Primary,
          on_click: StartSsoLogin,
        )),
      ],
    ),
  )
}
