import gleam/http
import gleam/http/request
import gleam/list
import gleeunit/should
import transport/http/middleware/cache_policy
import transport/session
import wisp

pub fn session_cookie_request_is_not_cached_test() {
  let request =
    test_request(http.Get)
    |> request.set_header("cookie", session.cookie_name <> "=opaque-token")

  let response = cache_policy.handle(request, fn() { wisp.ok() })

  list.key_find(response.headers, "cache-control")
  |> should.equal(Ok("no-store"))

  list.key_find(response.headers, "pragma")
  |> should.equal(Ok("no-cache"))
}

pub fn session_cookie_response_is_not_cached_test() {
  let request = test_request(http.Post)
  let response =
    cache_policy.handle(request, fn() {
      wisp.ok()
      |> wisp.set_header("set-cookie", "roxy_session=opaque-token; Path=/")
    })

  list.key_find(response.headers, "cache-control")
  |> should.equal(Ok("no-store"))
}

pub fn public_response_remains_cacheable_test() {
  let request = test_request(http.Get)
  let response = cache_policy.handle(request, fn() { wisp.ok() })

  list.key_find(response.headers, "cache-control")
  |> should.equal(Error(Nil))
}

fn test_request(method: http.Method) -> wisp.Request {
  request.new()
  |> request.set_method(method)
  |> request.set_body(wisp.create_canned_connection(
    <<>>,
    "test-secret-key-base-that-is-long-enough-for-wisp",
  ))
}
