import application/access
import gleam/http

pub type HttpError {
  NotFound
  MethodNotAllowed(List(http.Method))
  UnsupportedMediaType
  InvalidBody
  PayloadTooLarge
  TooManyRequests
  Access(access.AccessError)
}
