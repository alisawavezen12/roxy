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

pub type Model {
  Model(
    route: Route,
    auth: AuthState,
    user_page: UserPageState,
    user_tab: UserTab,
    auth_modal_open: Bool,
    settings_modal_open: Bool,
  )
}
