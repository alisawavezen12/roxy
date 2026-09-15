import api/auth/auth
import api/user/user as user_api
import app/message.{
  type Message, AuthChecked, CloseAuthModal, CloseSettingsModal, NoOp,
  OpenAuthModal, OpenSettingsModal, PostContentChanged, SelectUserTab,
  StartSsoLogin, UserLoaded,
}
import app/model.{
  type Model, Authenticated, Checking, Model, Unauthenticated, Unavailable,
  UserLoadFailed, UserLoaded as UserLoadedState, UserLoading, UserNotFound,
}
import lustre/effect.{type Effect}
import modules/authenticated_user/authenticated_user
import routes/route.{type Route, User}

pub fn init(route: Route) -> #(Model, Effect(Message)) {
  #(
    Model(
      route:,
      auth: Checking,
      user_page: UserLoading,
      user_tab: model.Wall,
      auth_modal_open: False,
      settings_modal_open: False,
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
