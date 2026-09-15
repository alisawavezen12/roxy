import application/dependencies
import gleam/dynamic/decode
import gleam/json
import gleam/option
import pog
import transport/http/protocol/status
import transport/transport_context
import wisp

pub fn handle(
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case transport_context.principal(context) {
    option.None -> wisp.response(status.unauthorized)
    option.Some(principal) ->
      case
        user_name(
          dependencies.postgres,
          principal.user_id,
          dependencies.config.postgres.query_timeout,
        )
      {
        Ok(name) ->
          json.object([#("user", json.object([#("name", json.string(name))]))])
          |> json.to_string
          |> wisp.json_response(status.ok)
        Error(_) -> wisp.response(status.internal_server_error)
      }
  }
}

fn user_name(
  connection: pog.Connection,
  user_id: String,
  timeout: Int,
) -> Result(String, pog.QueryError) {
  let query =
    pog.query(
      "select coalesce(nullif(trim(concat_ws(' ', first_name, last_name)), ''), email) from users where id = $1",
    )
    |> pog.parameter(pog.text(user_id))
    |> pog.returning(decode.subfield([0], decode.string, decode.success))
    |> pog.timeout(timeout)
  case pog.execute(query, connection) {
    Ok(pog.Returned(rows: [name, ..], ..)) -> Ok(name)
    Ok(_) -> Error(pog.UnexpectedResultType([]))
    Error(error) -> Error(error)
  }
}
