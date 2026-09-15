import routes/route.{type Route}

pub type AuthState {
  Checking
  Unauthenticated
  Authenticated(name: String)
  Unavailable
}

pub type Model {
  Model(route: Route, auth: AuthState, auth_modal_open: Bool)
}
