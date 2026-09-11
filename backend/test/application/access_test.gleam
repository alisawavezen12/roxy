import application/access
import gleam/option
import gleeunit/should

pub fn missing_principal_is_unauthenticated_test() {
  access.authorize(access.Authenticated, option.None)
  |> should.equal(Error(access.Unauthenticated))
}

pub fn missing_permission_is_unauthenticated_test() {
  access.authorize(access.Permission("admin"), option.None)
  |> should.equal(Error(access.Unauthenticated))
}

pub fn principal_without_permission_is_forbidden_test() {
  let principal = access.principal("user-1")

  access.authorize(access.Permission("admin"), option.Some(principal))
  |> should.equal(Error(access.Forbidden))
}

pub fn principal_with_permission_is_authorized_test() {
  let principal = access.principal_with_permissions("user-1", ["admin"])

  access.authorize(access.Permission("admin"), option.Some(principal))
  |> should.equal(Ok(option.Some(principal)))
}
