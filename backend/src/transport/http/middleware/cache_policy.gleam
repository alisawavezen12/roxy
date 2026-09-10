import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/result
import transport/session
import wisp

pub fn handle(
  http_request: wisp.Request,
  next: fn() -> wisp.Response,
) -> wisp.Response {
  let response = next()
  case private_or_session_response(http_request, response) {
    True ->
      response
      |> wisp.set_header("cache-control", "no-store")
      |> wisp.set_header("pragma", "no-cache")
    False -> response
  }
}

fn private_or_session_response(
  http_request: wisp.Request,
  response: wisp.Response,
) -> Bool {
  has_session_cookie(http_request) || has_set_cookie(response)
}

fn has_session_cookie(http_request: wisp.Request) -> Bool {
  http_request
  |> request.get_cookies
  |> list.key_find(session.cookie_name)
  |> result.is_ok
}

fn has_set_cookie(response: wisp.Response) -> Bool {
  response
  |> response.get_header("set-cookie")
  |> result.is_ok
}
