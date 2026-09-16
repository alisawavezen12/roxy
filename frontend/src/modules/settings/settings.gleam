import api/auth/auth
import app/message.{
  type Message, BioChanged, CloseSettingsModal, Logout, NoOp, SaveBio,
  SyncProfile,
}
import app/model.{
  type AuthState, type BioState, type LogoutState, type SyncState, Authenticated,
  BioIdle, BioSaving, LoggingOut, LogoutIdle, SyncIdle, SyncSucceeded, Syncing,
}
import gleam/int

import gleam/string
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element, element}
import lustre/element/html
import lustre/event
import shared/api/error as api_error
import ui/components/button/button
import ui/components/modal/modal
import ui/components/textarea/textarea

pub fn sync_profile() -> Effect(auth.CurrentUserResult) {
  auth.sync_profile()
}

pub fn logout() -> Effect(auth.LogoutResult) {
  auth.logout()
}

pub fn stylesheet() -> Element(message) {
  html.div([attribute.class("settings__styles")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/modules/settings/settings.css"),
    ]),
    button.stylesheet(),
    modal.stylesheet(),
    textarea.stylesheet(),
  ])
}

pub fn view(
  auth_state: AuthState,
  modal_open: Bool,
  sync_state: SyncState,
  logout_state: LogoutState,
  bio: String,
  saved_bio: String,
  bio_state: BioState,
) -> Element(Message) {
  case modal_open, auth_state {
    True, Authenticated(_profile) ->
      modal.view(modal.Config(
        title: "Settings",
        close_label: "Close settings dialog",
        on_close: CloseSettingsModal,
        on_ignore: NoOp,
        children: content(sync_state, logout_state, bio, saved_bio, bio_state),
      ))
    _, _ -> html.div([], [])
  }
}

fn content(
  sync_state: SyncState,
  logout_state: LogoutState,
  bio: String,
  saved_bio: String,
  bio_state: BioState,
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
    html.div([attribute.class("settings__section")], [
      html.div([attribute.class("settings__profile-sync")], [
        html.p([attribute.class("settings__copy")], [
          html.text("To change your avatar or username, go to "),
          html.a(
            [
              attribute.class("settings__profile-link"),
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
      html.div([attribute.class("settings__bio-section")], [
        html.div([attribute.class("settings__bio-heading")], [
          element("label", [attribute.class("settings__bio-label")], [
            html.text("Bio"),
          ]),
          html.p([attribute.class(bio_counter_class(bio))], [
            html.text(bio_counter(bio)),
          ]),
        ]),
        textarea.view(
          textarea.Config(
            value: bio,
            placeholder: "Tell people about yourself",
            label: "Bio",
            on_input: BioChanged,
            on_keydown: fn(key) {
              case key {
                "Escape" -> CloseSettingsModal
                _ -> NoOp
              }
            },
          ),
        ),
        html.div(
          [
            attribute.class("settings__bio-save"),
            event.prevent_default(event.on_mouse_down(NoOp)),
          ],
          [
            button.view(button.Config(
              label: bio_save_label(bio_state),
              size: button.Small,
              variant: button.Primary,
              on_click: SaveBio,
              disabled: is_bio_saving(bio_state)
                || bio == saved_bio
                || string.length(bio) > api_error.bio_max_length,
            )),
          ],
        ),
      ]),
    ]),
    html.div([attribute.class("settings__logout")], [
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

fn bio_counter(bio: String) -> String {
  int.to_string(string.length(bio))
  <> " / "
  <> int.to_string(api_error.bio_max_length)
}

fn bio_counter_class(bio: String) -> String {
  case string.length(bio) > api_error.bio_max_length {
    True -> "settings__bio-counter settings__bio-counter--invalid"
    False -> "settings__bio-counter"
  }
}

fn bio_save_label(bio_state: BioState) -> String {
  case bio_state {
    BioSaving -> "Saving..."
    BioIdle -> "Save bio"
  }
}

fn is_bio_saving(bio_state: BioState) -> Bool {
  case bio_state {
    BioSaving -> True
    BioIdle -> False
  }
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
