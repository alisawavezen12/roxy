import gleeunit/should
import transport/http/handlers/auth/sso

pub fn return_to_allows_same_frontend_origin_test() {
  sso.allowed_return_to(
    "http://localhost:1234/user/example?tab=posts",
    "http://localhost:1234",
  )
  |> should.equal(True)
}

pub fn return_to_rejects_other_origin_test() {
  sso.allowed_return_to(
    "https://evil.example/user/example",
    "http://localhost:1234",
  )
  |> should.equal(False)
}

pub fn return_to_rejects_lookalike_host_test() {
  sso.allowed_return_to(
    "http://localhost:1234.evil.example/user/example",
    "http://localhost:1234",
  )
  |> should.equal(False)
}
