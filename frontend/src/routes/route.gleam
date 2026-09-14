import gleam/string

pub type Route {
  Home
  User(id: String)
  NotFound
}

pub fn from_path(path: String) -> Route {
  case path {
    "/" -> Home
    value ->
      case user_id(value) {
        Ok(id) -> User(id:)
        Error(_) -> NotFound
      }
  }
}

fn user_id(path: String) -> Result(String, Nil) {
  case string.split(path, "/") {
    ["", "user", id] if id != "" -> Ok(id)
    _ -> Error(Nil)
  }
}
