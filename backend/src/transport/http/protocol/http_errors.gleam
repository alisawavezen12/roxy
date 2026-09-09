import application/access
import gleam/http

pub type HttpError {
  NotFound
  MethodNotAllowed(List(http.Method))
  UnsupportedMediaType
  InvalidBody
  PayloadTooLarge
  Access(access.AccessError)
}
