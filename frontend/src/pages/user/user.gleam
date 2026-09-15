import app/message.{type Message, CloseAuthModal, NoOp, StartSsoLogin}
import app/model.{
  type AuthState, type UserPageState, Authenticated, Checking, Unauthenticated,
  Unavailable, UserLoadFailed, UserLoaded, UserLoading, UserNotFound,
}

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
    html.section([attribute.class("user-page__posts")], posts()),
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
      html.a(
        [
          attribute.class("user-page__viewer-link"),
          attribute.href("/user/" <> current_user.id),
          attribute.title("Open your profile"),
        ],
        [identity_panel.avatar(current_user)],
      ),
    ]
    Checking -> [
      html.p([attribute.class("user-page__auth-status")], [
        html.text("Checking session…"),
      ]),
    ]
    Unauthenticated | Unavailable -> []
  }
}

fn posts() -> List(Element(Message)) {
  [empty_state("mail.svg", "This user has no posts yet.")]
}

fn empty_state(icon: String, message: String) -> Element(Message) {
  html.div([attribute.class("user-page__empty")], [
    html.span(
      [
        attribute.class("user-page__empty-icon"),
        attribute.attribute("aria-hidden", "true"),
        attribute.style("--empty-icon", "url('/svg/" <> icon <> "')"),
      ],
      [],
    ),
    html.p([], [html.text(message)]),
  ])
}

fn profile(state: UserPageState) -> List(Element(Message)) {
  case state {
    UserLoading -> [status("Loading user…")]
    UserLoaded(profile) -> [identity_panel.view(profile)]
    UserNotFound -> [empty_state("user.svg", "This user does not exist.")]
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
      on_ignore: NoOp,
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
