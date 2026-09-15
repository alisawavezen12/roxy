import api/auth/auth
import app/message.{
  type Message, CloseAuthModal, CloseSettingsModal, NoOp, OpenAuthModal,
  OpenSettingsModal, StartSsoLogin,
}
import app/model.{type AuthState, Authenticated, Checking, Unavailable}
import gleam/option
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/user
import ui/components/button/button
import ui/components/modal/modal

pub fn load() -> Effect(auth.CurrentUserResult) {
  auth.load_current_user()
}

pub fn start_login() -> Effect(message) {
  auth.start_sso_login()
}

pub fn stylesheet() -> Element(message) {
  html.div([attribute.class("authenticated-user__styles")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/modules/authenticated_user/authenticated_user.css"),
    ]),
    button.stylesheet(),
    modal.stylesheet(),
  ])
}

pub fn view(
  auth_state: AuthState,
  auth_modal_open: Bool,
  settings_modal_open: Bool,
) -> Element(Message) {
  html.div([], [
    html.aside([attribute.class("authenticated-user")], content(auth_state)),
    auth_modal_view(auth_state, auth_modal_open),
    settings_modal_view(settings_modal_open),
  ])
}

fn content(auth_state: AuthState) -> List(Element(Message)) {
  case auth_state {
    Authenticated(profile) -> [
      html.a(
        [
          attribute.class("authenticated-user__link"),
          attribute.href("/user/" <> profile.id),
          attribute.title("Go to my profile"),
        ],
        [avatar(profile)],
      ),
      button.view(button.Config(
        label: "Settings",
        size: button.ExtraLarge,
        variant: button.Icon("settings.svg"),
        on_click: OpenSettingsModal,
        disabled: False,
      )),
    ]
    Checking -> [login_button()]
    Unavailable -> [login_button()]
    _ -> [login_button()]
  }
}

fn login_button() -> Element(Message) {
  html.button(
    [
      attribute.class("authenticated-user__login"),
      attribute.type_("button"),
      attribute.attribute("aria-label", "Sign in with Dobrunia Auth"),
      attribute.title("Sign in with Dobrunia Auth"),
      event.on_click(OpenAuthModal),
    ],
    [html.span([attribute.attribute("aria-hidden", "true")], [])],
  )
}

fn auth_modal_view(
  auth_state: AuthState,
  modal_open: Bool,
) -> Element(Message) {
  case modal_open {
    True -> auth_modal(auth_state)
    False -> html.div([], [])
  }
}

fn settings_modal_view(modal_open: Bool) -> Element(Message) {
  case modal_open {
    True ->
      modal.view(
        modal.Config(
          title: "Settings",
          close_label: "Close settings dialog",
          on_close: CloseSettingsModal,
          on_ignore: NoOp,
          children: [],
        ),
      )
    False -> html.div([], [])
  }
}

fn auth_modal(auth_state: AuthState) -> Element(Message) {
  let message = case auth_state {
    Unavailable -> "Unable to check the session. Please try again."
    _ -> "Sign in with Dobrunia Auth to continue using Roxy."
  }
  modal.view(
    modal.Config(
      title: "Sign in to Roxy",
      close_label: "Close sign-in dialog",
      on_close: CloseAuthModal,
      on_ignore: NoOp,
      children: [
        html.p([attribute.class("authenticated-user__auth-copy")], [
          html.text(message),
        ]),
        button.view(button.Config(
          label: "Sign in with Dobrunia Auth",
          size: button.Large,
          variant: button.Primary,
          on_click: StartSsoLogin,
          disabled: False,
        )),
      ],
    ),
  )
}

fn avatar(profile: user.User) -> Element(Message) {
  case profile.avatar_url {
    option.Some(url) if url != "" ->
      html.img([
        attribute.class("authenticated-user__avatar"),
        attribute.src(url),
        attribute.alt(user.display_name(profile) <> " avatar"),
      ])
    _ ->
      html.div(
        [
          attribute.class("authenticated-user__avatar"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [html.text(user.avatar_letter(profile))],
      )
  }
}
