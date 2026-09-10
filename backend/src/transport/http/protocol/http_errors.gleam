import application/access
import gleam/http

pub type HttpError {
  NotFound
  MethodNotAllowed(List(http.Method))
  UnsupportedMediaType
  InvalidBody
  PayloadTooLarge
  TooManyRequests
  CsrfForbidden
  Access(access.AccessError)
}
