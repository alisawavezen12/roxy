import application/access
import gleam/http

pub type HttpError {
  NotFound
  MethodNotAllowed(List(http.Method))
  UnsupportedMediaType
  PayloadTooLarge
  Access(access.AccessError)
}
