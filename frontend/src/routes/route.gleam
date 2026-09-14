pub type Route {
  Home
  NotFound
}

pub fn from_path(path: String) -> Route {
  case path {
    "/" -> Home
    _ -> NotFound
  }
}
