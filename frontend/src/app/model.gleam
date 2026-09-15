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

pub type Model {
  Model(
    route: Route,
    auth: AuthState,
    user_page: UserPageState,
    auth_modal_open: Bool,
  )
}
