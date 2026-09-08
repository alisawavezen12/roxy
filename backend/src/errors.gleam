import gleam/http

pub type Error {
  NotFound
  MethodNotAllowed(List(http.Method))
  Unauthorized
  Forbidden
  Internal
}
