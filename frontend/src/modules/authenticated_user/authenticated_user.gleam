import api/auth/auth
import app/message.{
  type Message, CloseAuthModal, CloseSettingsModal, Logout, NoOp, OpenAuthModal,
  OpenSettingsModal, StartSsoLogin, SyncProfile,
}
import app/model.{
  type AuthState, type LogoutState, type SyncState, Authenticated, Checking,
  LoggingOut, LogoutIdle, SyncIdle, SyncSucceeded, Syncing, Unavailable,
}
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

pub fn sync_profile() -> Effect(auth.CurrentUserResult) {
  auth.sync_profile()
}

pub fn alert(message: String) -> Effect(message) {
  auth.alert_user(message)
}

pub fn logout() -> Effect(auth.LogoutResult) {
  auth.logout()
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
  sync_state: SyncState,
  logout_state: LogoutState,
) -> Element(Message) {
  html.div([], [
    html.aside([attribute.class("authenticated-user")], content(auth_state)),
    auth_modal_view(auth_state, auth_modal_open),
    settings_modal_view(
      settings_modal_open,
      auth_state,
      sync_state,
      logout_state,
    ),
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

fn settings_modal_view(
  modal_open: Bool,
  auth_state: AuthState,
  sync_state: SyncState,
  logout_state: LogoutState,
) -> Element(Message) {
  case modal_open, auth_state {
    True, Authenticated(_profile) ->
      modal.view(modal.Config(
        title: "Settings",
        close_label: "Close settings dialog",
        on_close: CloseSettingsModal,
        on_ignore: NoOp,
        children: settings_content(sync_state, logout_state),
      ))
    _, _ -> html.div([], [])
  }
}

fn settings_content(
  sync_state: SyncState,
  logout_state: LogoutState,
) -> List(Element(Message)) {
  let sync_label = case sync_state {
    Syncing -> "Synchronizing..."
    SyncSucceeded -> "Synchronized"
    SyncIdle -> "Synchronize profile"
  }
  let sync_icon = case sync_state {
    Syncing -> button.IconAnimated("sync.svg", button.Spin)
    _ -> button.Icon("sync.svg")
  }
  [
    html.div([attribute.class("authenticated-user__settings-section")], [
      html.p([attribute.class("authenticated-user__settings-copy")], [
        html.text("To change your avatar or username, go to "),
        html.a(
          [
            attribute.class("authenticated-user__profile-link"),
            attribute.href("https://auth.dobrunia.guru/profile"),
            attribute.attribute("target", "_blank"),
            attribute.attribute("rel", "noopener noreferrer"),
          ],
          [html.text("Dobrunia profile")],
        ),
        html.text(
          " and update your profile there. Then synchronize to update your username, avatar, first name, and last name in Roxy.",
        ),
      ]),
      button.view(button.Config(
        label: sync_label,
        size: button.Medium,
        variant: sync_icon,
        on_click: SyncProfile,
        disabled: is_syncing(sync_state),
      )),
    ]),
    html.div([attribute.class("authenticated-user__settings-logout")], [
      button.view(button.Config(
        label: logout_label(logout_state),
        size: button.Medium,
        variant: button.Danger,
        on_click: Logout,
        disabled: is_logging_out(logout_state),
      )),
    ]),
  ]
}

fn logout_label(logout_state: LogoutState) -> String {
  case logout_state {
    LoggingOut -> "Logging out..."
    LogoutIdle -> "Log out"
  }
}

fn is_logging_out(logout_state: LogoutState) -> Bool {
  case logout_state {
    LoggingOut -> True
    LogoutIdle -> False
  }
}

fn is_syncing(sync_state: SyncState) -> Bool {
  case sync_state {
    Syncing -> True
    _ -> False
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
