import api/auth/auth
import app/message.{
  type Message, AuthChecked, CloseAuthModal, NoOp, OpenAuthModal, StartSsoLogin,
}
import app/model.{
  type Model, Authenticated, Checking, Model, Unauthenticated, Unavailable,
}

import gleam/string
import lustre/effect.{type Effect}
import routes/route.{type Route, User}

pub fn init(route: Route) -> #(Model, Effect(Message)) {
  let auth = case route {
    User(_) -> Checking
    _ -> Unauthenticated
  }
  #(Model(route:, auth:, auth_modal_open: False), load_auth_for(route))
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    AuthChecked(result) -> apply_auth_result(model, result)
    OpenAuthModal -> #(Model(..model, auth_modal_open: True), effect.none())
    CloseAuthModal -> #(Model(..model, auth_modal_open: False), effect.none())
    StartSsoLogin -> #(model, auth.start_sso_login())
    NoOp -> #(model, effect.none())
  }
}

fn load_auth_for(route: Route) -> Effect(Message) {
  case route {
    User(_) -> auth.load_current_user() |> effect.map(AuthChecked)
    _ -> effect.none()
  }
}

fn apply_auth_result(
  model: Model,
  result: String,
) -> #(Model, Effect(Message)) {
  case string.split_once(result, ":") {
    Ok(#("authenticated", name)) if name != "" -> #(
      Model(..model, auth: Authenticated(name), auth_modal_open: False),
      effect.none(),
    )
    _ ->
      case result {
        "unauthenticated" -> #(
          Model(..model, auth: Unauthenticated, auth_modal_open: True),
          effect.none(),
        )
        _ -> #(
          Model(..model, auth: Unavailable, auth_modal_open: True),
          effect.none(),
        )
      }
  }
}
