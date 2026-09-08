import gleam/http
import gleam/http/request
import gleeunit
import gleeunit/should
import http/router

pub fn main() {
  gleeunit.main()
}

pub fn test_health_route_returns_ok() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/health")

  let response = router.handle(request)

  response.status
  |> should.equal(200)
}

pub fn test_unknown_route_returns_not_found() {
  let request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/unknown")

  let response = router.handle(request)

  response.status
  |> should.equal(404)
}

pub fn test_health_route_requires_get() {
  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_path("/health")

  let response = router.handle(request)

  response.status
  |> should.equal(404)
}
