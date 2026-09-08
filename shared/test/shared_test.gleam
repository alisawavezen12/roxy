import gleam/json
import gleeunit
import shared
import shared/health.{Health}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn health_json_roundtrip_test() {
  let original = Health(ok: True, db: "ok", service: shared.app_name)
  let assert Ok(parsed) =
    json.parse(from: health.to_string(original), using: health.decoder())

  assert parsed == original
}

pub fn unhealthy_json_roundtrip_test() {
  let original = Health(ok: False, db: "error", service: shared.app_name)
  let assert Ok(parsed) =
    json.parse(from: health.to_string(original), using: health.decoder())

  assert parsed == original
}

pub fn health_rejects_wrong_field_type_test() {
  let assert Error(_) =
    json.parse(
      from: "{\"ok\":\"true\",\"db\":\"ok\",\"service\":\"roxy\"}",
      using: health.decoder(),
    )
}

pub fn health_rejects_missing_fields_test() {
  let assert Error(_) = json.parse(from: "{}", using: health.decoder())
}
