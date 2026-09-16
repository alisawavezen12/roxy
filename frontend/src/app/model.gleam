import gleam/option.{type Option}
import routes/route.{type Route}
import shared/user.{type User}

pub type AuthState {
  Checking
  Unauthenticated
  Authenticated(User)
  Unavailable
}

pub type UserPageState {
  UserLoading
  UserLoaded(User)
  UserNotFound
  UserLoadFailed
}

pub type UserTab {
  Wall
  Board
}

pub type SyncState {
  SyncIdle
  Syncing
  SyncSucceeded
}

pub type LogoutState {
  LogoutIdle
  LoggingOut
}

pub type BioState {
  BioIdle
  BioSaving
}

pub type NotificationKind {
  NotificationSuccess
  NotificationError
}

pub type Notification {
  Notification(kind: NotificationKind, message: String, tooltip: String)
}

pub type Model {
  Model(
    route: Route,
    auth: AuthState,
    user_page: UserPageState,
    user_tab: UserTab,
    auth_modal_open: Bool,
    settings_modal_open: Bool,
    sync_state: SyncState,
    logout_state: LogoutState,
    bio: String,
    saved_bio: String,
    bio_state: BioState,
    notification: Option(Notification),
    post_content: String,
  )
}
