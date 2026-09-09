import gleam/list
import gleam/option.{type Option, None, Some}

pub type Access {
  Public
  Authenticated
  Permission(String)
}

pub type Principal {
  Principal(user_id: String, permissions: List(String))
}

pub fn authorize(
  access: Access,
  principal: Option(Principal),
) -> Result(Option(Principal), AccessError) {
  case access, principal {
    Public, principal -> Ok(principal)
    Authenticated, None -> Error(Unauthenticated)
    Authenticated, Some(principal) -> Ok(Some(principal))
    Permission(_), None -> Error(Unauthenticated)
    Permission(permission), Some(principal) ->
      case list.contains(principal.permissions, permission) {
        True -> Ok(Some(principal))
        False -> Error(Forbidden)
      }
  }
}

pub fn principal(user_id: String) -> Principal {
  Principal(user_id:, permissions: [])
}

pub fn user_id(principal: Option(Principal)) -> Option(String) {
  case principal {
    None -> None
    Some(Principal(user_id:, ..)) -> Some(user_id)
  }
}

pub type AccessError {
  Unauthenticated
  Forbidden
}
