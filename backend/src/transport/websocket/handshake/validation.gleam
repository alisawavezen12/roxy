import application/access
import config/origins
import gleam/http
import gleam/http/request
import gleam/list
import gleam/string

pub type HandshakeError {
  MethodNotAllowed(List(http.Method))
  OriginNotAllowed
  InvalidHandshake
  Access(access.AccessError)
}

pub fn validate(
  http_request: request.Request(body),
  methods: List(http.Method),
  origins: origins.OriginsConfig,
) -> Result(Nil, HandshakeError) {
  case list.contains(methods, http_request.method) {
    False -> Error(MethodNotAllowed(methods))
    True ->
      case origin_is_allowed(http_request, origins.allowed) {
        False -> Error(OriginNotAllowed)
        True -> validate_upgrade_headers(http_request)
      }
  }
}

fn origin_is_allowed(
  http_request: request.Request(body),
  allowed: List(String),
) -> Bool {
  case request.get_header(http_request, "origin") {
    Ok(origin) -> list.contains(allowed, string.lowercase(origin))
    Error(_) -> False
  }
}

fn validate_upgrade_headers(
  http_request: request.Request(body),
) -> Result(Nil, HandshakeError) {
  case
    request.get_header(http_request, "upgrade"),
    request.get_header(http_request, "connection"),
    request.get_header(http_request, "sec-websocket-key"),
    request.get_header(http_request, "sec-websocket-version")
  {
    Ok(upgrade), Ok(connection), Ok(key), Ok("13") ->
      case
        string.lowercase(upgrade) == "websocket"
        && key != ""
        && header_contains_token(connection, "upgrade")
      {
        True -> Ok(Nil)
        False -> invalid()
      }
    _, _, _, _ -> invalid()
  }
}

fn invalid() -> Result(Nil, HandshakeError) {
  Error(InvalidHandshake)
}

fn header_contains_token(value: String, token: String) -> Bool {
  value
  |> string.split(",")
  |> list.any(fn(value) { string.lowercase(string.trim(value)) == token })
}
