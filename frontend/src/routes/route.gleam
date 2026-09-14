pub type Route {
  Home
  User
  NotFound
}

pub fn from_path(path: String) -> Route {
  case path {
    "/" -> Home
    "/user" -> User
    _ -> NotFound
  }
}
