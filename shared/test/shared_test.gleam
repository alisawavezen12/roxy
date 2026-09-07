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
