/// Domain-level user data and rules belong here.
///
/// This module intentionally has no dependency on Lustre, HTML, HTTP, or API
/// transport details. Add user-related business types and pure transformations
/// here as the product model grows.
pub type User {
  User(id: String, display_name: String)
}

pub fn display_name(user: User) -> String {
  user.display_name
}
