import application/access
import gleam/option
import gleeunit/should
import transport/transport_context

pub fn verified_principal_is_attached_without_changing_request_id_test() {
  let context = transport_context.new()
  let principal = access.Principal("user-1", ["posts:write"])
  let authenticated =
    transport_context.with_principal(context, option.Some(principal))

  transport_context.request_id(authenticated)
  |> should.equal(transport_context.request_id(context))
  transport_context.principal(authenticated)
  |> should.equal(option.Some(principal))
}

pub fn new_context_is_anonymous_test() {
  transport_context.new()
  |> transport_context.principal
  |> should.equal(option.None)
}
