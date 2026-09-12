import gleam/json
import gleeunit
import shared/api/error

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn api_error_json_decodes_test() {
  let assert Ok(error) =
    json.parse(
      from: "{\"error\":{\"code\":\"not_found\",\"message\":\"Not found\",\"request_id\":\"req_test\"}}",
      using: error.decoder(),
    )

  assert error
    == error.ApiError(
      code: error.not_found_code,
      message: error.not_found_message,
      request_id: "req_test",
    )
}
