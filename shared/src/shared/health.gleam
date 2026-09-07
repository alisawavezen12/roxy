import gleam/dynamic/decode
import gleam/json

pub type Health {
  Health(ok: Bool, db: String, service: String)
}

pub fn decoder() -> decode.Decoder(Health) {
  use ok <- decode.field("ok", decode.bool)
  use db <- decode.field("db", decode.string)
  use service <- decode.field("service", decode.string)
  decode.success(Health(ok:, db:, service:))
}

pub fn to_json(health: Health) -> json.Json {
  json.object([
    #("ok", json.bool(health.ok)),
    #("db", json.string(health.db)),
    #("service", json.string(health.service)),
  ])
}

pub fn to_string(health: Health) -> String {
  json.to_string(to_json(health))
}
