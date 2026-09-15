import app/message.{type Message, CloseAuthModal, StartSsoLogin}
import app/model.{
  type AuthState, type UserPageState, Authenticated, Checking, Unauthenticated,
  Unavailable, UserLoadFailed, UserLoaded, UserLoading, UserNotFound,
}
import shared/user

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/identity_panel/identity_panel
import ui/components/button/button
import ui/components/modal/modal

pub fn view(
  profile_state: UserPageState,
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
    html.aside([attribute.class("user-page__viewer")], viewer(auth)),
    html.section([attribute.class("user-page__posts")], []),
    html.section(
      [attribute.class("user-page__profile")],
      profile(profile_state),
    ),
    ..modal_views
  ])
}

fn viewer(auth: AuthState) -> List(Element(Message)) {
  case auth {
    Authenticated(current_user) -> [
      identity_panel.avatar(current_user),
      html.p([attribute.class("user-page__viewer-name")], [
        html.text(user.display_name(current_user)),
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

fn profile(state: UserPageState) -> List(Element(Message)) {
  case state {
    UserLoading -> [status("Loading user…")]
    UserLoaded(profile) -> [identity_panel.view(profile)]
    UserNotFound -> [status("This user does not exist.")]
    UserLoadFailed -> [status("Unable to load this user.")]
  }
}

fn status(message: String) -> Element(Message) {
  html.p([attribute.class("user-page__status")], [html.text(message)])
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
