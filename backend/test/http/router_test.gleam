import gleam/http
import gleam/http/request
import gleeunit
import gleeunit/should
import http/router
import wisp

pub fn main() {
  gleeunit.main()
}

pub fn health_route_returns_ok_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/health")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request)

  response.status
  |> should.equal(200)
}

pub fn unknown_route_returns_not_found_test() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/unknown")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request)

  response.status
  |> should.equal(404)
}

pub fn health_route_requires_get_test() {
  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_path("/health")
    |> request.set_body(wisp.create_canned_connection(
      <<>>,
      "test-secret-key-base-that-is-long-enough-for-wisp",
    ))

  let response = router.handle(request)

  response.status
  |> should.equal(404)
}
