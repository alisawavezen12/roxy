import api/auth/auth
import api/user/user as user_api
import app/message.{
  type Message, AuthChecked, BioChanged, BioSaved, CloseAuthModal,
  CloseSettingsModal, Logout, LogoutFinished, NoOp, NotificationExpired,
  OpenAuthModal, OpenSettingsModal, PostContentChanged, SaveBio, SelectUserTab,
  StartSsoLogin, SyncFinished, SyncProfile, UserLoaded,
}
import app/model.{
  type Model, Authenticated, BioIdle, BioSaving, Checking, LoggingOut,
  LogoutIdle, Model, Notification, NotificationError, NotificationSuccess,
  SyncIdle, SyncSucceeded, Syncing, Unauthenticated, Unavailable, UserLoadFailed,
  UserLoaded as UserLoadedState, UserLoading, UserNotFound,
}
import gleam/option
import gleam/string
import lustre/effect.{type Effect}
import modules/authenticated_user/authenticated_user
import modules/settings/settings
import routes/route.{type Route, User}
import shared/api/error as api_error
import shared/user as shared_user
import ui/components/notification/notification

pub fn init(route: Route) -> #(Model, Effect(Message)) {
  #(
    Model(
      route:,
      auth: Checking,
      user_page: UserLoading,
      user_tab: model.Wall,
      auth_modal_open: False,
      settings_modal_open: False,
      sync_state: SyncIdle,
      logout_state: LogoutIdle,
      bio: "",
      saved_bio: "",
      bio_state: BioIdle,
      notification: option.None,
      post_content: "",
    ),
    load(route),
  )
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    AuthChecked(result) -> apply_auth_result(model, result)
    UserLoaded(result) -> apply_user_result(model, result)
    BioChanged(bio) -> #(Model(..model, bio:), effect.none())
    SaveBio -> save_bio(model)
    BioSaved(result) -> apply_bio_result(model, result)
    NotificationExpired -> #(
      Model(..model, notification: option.None),
      effect.none(),
    )
    PostContentChanged(content) -> #(
      Model(..model, post_content: content),
      effect.none(),
    )
    SelectUserTab(tab) -> #(Model(..model, user_tab: tab), effect.none())
    OpenAuthModal -> #(Model(..model, auth_modal_open: True), effect.none())
    CloseAuthModal -> #(Model(..model, auth_modal_open: False), effect.none())
    OpenSettingsModal -> #(
      Model(..model, settings_modal_open: True),
      effect.none(),
    )
    CloseSettingsModal -> #(
      Model(..model, settings_modal_open: False),
      effect.none(),
    )
    StartSsoLogin -> #(model, authenticated_user.start_login())
    SyncProfile -> sync_profile(model)
    SyncFinished(result) -> apply_sync_result(model, result)
    Logout -> logout(model)
    LogoutFinished(result) -> apply_logout_result(model, result)
    NoOp -> #(model, effect.none())
  }
}

fn load(route: Route) -> Effect(Message) {
  let auth_effect = authenticated_user.load() |> effect.map(AuthChecked)
  case route {
    User(id) ->
      effect.batch([
        auth_effect,
        user_api.load(id) |> effect.map(UserLoaded),
      ])
    _ -> auth_effect
  }
}

fn apply_auth_result(
  model: Model,
  result: auth.CurrentUserResult,
) -> #(Model, Effect(Message)) {
  case result {
    auth.SignedIn(user) -> #(
      Model(
        ..model,
        auth: Authenticated(user),
        bio: bio_value(user),
        saved_bio: bio_value(user),
        auth_modal_open: False,
      ),
      effect.none(),
    )
    auth.SignedOut -> #(
      Model(..model, auth: Unauthenticated, auth_modal_open: False),
      effect.none(),
    )
    auth.Failed -> #(
      Model(..model, auth: Unavailable, auth_modal_open: False),
      effect.none(),
    )
  }
}

fn sync_profile(model: Model) -> #(Model, Effect(Message)) {
  case model.sync_state {
    Syncing -> #(model, effect.none())
    _ -> #(
      Model(..model, sync_state: Syncing),
      settings.sync_profile()
        |> effect.map(SyncFinished),
    )
  }
}

fn apply_sync_result(
  model: Model,
  result: auth.CurrentUserResult,
) -> #(Model, Effect(Message)) {
  case result {
    auth.SignedIn(profile) -> #(
      Model(
        ..model,
        auth: Authenticated(profile),
        bio: bio_value(profile),
        saved_bio: bio_value(profile),
        user_page: synced_user_page(model, profile),
        sync_state: SyncSucceeded,
      ),
      effect.none(),
    )
    auth.SignedOut ->
      show_error(model, "Не удалось синхронизировать профиль. Сессия истекла.")
    auth.Failed ->
      show_error(
        model,
        "Не удалось синхронизировать профиль. Попробуйте ещё раз.",
      )
  }
}

fn logout(model: Model) -> #(Model, Effect(Message)) {
  case model.logout_state {
    LoggingOut -> #(model, effect.none())
    LogoutIdle -> #(
      Model(..model, logout_state: LoggingOut),
      settings.logout()
        |> effect.map(LogoutFinished),
    )
  }
}

fn apply_logout_result(
  model: Model,
  result: auth.LogoutResult,
) -> #(Model, Effect(Message)) {
  case result {
    auth.LoggedOut -> #(
      Model(
        ..model,
        auth: Unauthenticated,
        settings_modal_open: False,
        logout_state: LogoutIdle,
      ),
      effect.none(),
    )
    auth.LogoutFailed ->
      show_error(
        Model(..model, logout_state: LogoutIdle),
        "Не удалось выйти из аккаунта. Попробуйте ещё раз.",
      )
  }
}

fn save_bio(model: Model) -> #(Model, Effect(Message)) {
  case model.bio_state {
    BioSaving -> #(model, effect.none())
    BioIdle ->
      case bio_too_long(model.bio) {
        True -> show_error(model, api_error.bio_too_long_message)
        False -> #(
          Model(..model, bio_state: BioSaving),
          user_api.save_bio(model.bio) |> effect.map(BioSaved),
        )
      }
  }
}

fn apply_bio_result(
  model: Model,
  result: user_api.SaveBioResult,
) -> #(Model, Effect(Message)) {
  case result {
    user_api.BioSaved(profile) ->
      show_success(
        Model(
          ..model,
          auth: Authenticated(profile),
          user_page: synced_user_page(model, profile),
          bio: bio_value(profile),
          saved_bio: bio_value(profile),
          bio_state: BioIdle,
        ),
        "Bio saved successfully.",
      )
    user_api.BioSaveFailed(message) ->
      show_error(Model(..model, bio_state: BioIdle), message)
  }
}

fn show_success(model: Model, message: String) -> #(Model, Effect(Message)) {
  #(
    Model(
      ..model,
      notification: option.Some(Notification(
        NotificationSuccess,
        message,
        message,
      )),
    ),
    notification.dismiss_after()
      |> effect.map(fn(_) { NotificationExpired }),
  )
}

fn show_error(model: Model, message: String) -> #(Model, Effect(Message)) {
  #(
    Model(
      ..model,
      notification: option.Some(Notification(
        NotificationError,
        message,
        message,
      )),
    ),
    notification.dismiss_after()
      |> effect.map(fn(_) { NotificationExpired }),
  )
}

fn bio_too_long(bio: String) -> Bool {
  string.length(bio) > api_error.bio_max_length
}

fn bio_value(profile: shared_user.User) -> String {
  case profile.bio {
    option.Some(bio) -> bio
    option.None -> ""
  }
}

fn synced_user_page(
  model: Model,
  profile: shared_user.User,
) -> model.UserPageState {
  case model.route {
    User(id) if id == profile.id -> UserLoadedState(profile)
    _ -> model.user_page
  }
}

fn apply_user_result(
  model: Model,
  result: user_api.Result,
) -> #(Model, Effect(Message)) {
  let state = case result {
    user_api.Found(user) -> UserLoadedState(user)
    user_api.NotFound -> UserNotFound
    user_api.Failed -> UserLoadFailed
  }
  #(Model(..model, user_page: state), effect.none())
}
