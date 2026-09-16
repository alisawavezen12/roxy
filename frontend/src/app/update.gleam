import api/auth/auth
import api/user/user as user_api
import app/message.{
  type Message, AuthChecked, CloseAuthModal, CloseSettingsModal, Logout,
  LogoutFinished, NoOp, OpenAuthModal, OpenSettingsModal, PostContentChanged,
  SelectUserTab, StartSsoLogin, SyncFinished, SyncProfile, UserLoaded,
}
import app/model.{
  type Model, Authenticated, Checking, LoggingOut, LogoutIdle, Model, SyncIdle,
  SyncSucceeded, Syncing, Unauthenticated, Unavailable, UserLoadFailed,
  UserLoaded as UserLoadedState, UserLoading, UserNotFound,
}
import lustre/effect.{type Effect}
import modules/authenticated_user/authenticated_user
import routes/route.{type Route, User}
import shared/user as shared_user

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
      post_content: "",
    ),
    load(route),
  )
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    AuthChecked(result) -> apply_auth_result(model, result)
    UserLoaded(result) -> apply_user_result(model, result)
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
      Model(..model, auth: Authenticated(user), auth_modal_open: False),
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
      authenticated_user.sync_profile()
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
        user_page: synced_user_page(model, profile),
        sync_state: SyncSucceeded,
      ),
      effect.none(),
    )
    auth.SignedOut -> #(
      Model(..model, sync_state: SyncIdle),
      authenticated_user.alert(
        "Не удалось синхронизировать профиль. Сессия истекла.",
      ),
    )
    auth.Failed -> #(
      Model(..model, sync_state: SyncIdle),
      authenticated_user.alert(
        "Не удалось синхронизировать профиль. Попробуйте ещё раз.",
      ),
    )
  }
}

fn logout(model: Model) -> #(Model, Effect(Message)) {
  case model.logout_state {
    LoggingOut -> #(model, effect.none())
    LogoutIdle -> #(
      Model(..model, logout_state: LoggingOut),
      authenticated_user.logout()
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
    auth.LogoutFailed -> #(
      Model(..model, logout_state: LogoutIdle),
      authenticated_user.alert(
        "Не удалось выйти из аккаунта. Попробуйте ещё раз.",
      ),
    )
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
