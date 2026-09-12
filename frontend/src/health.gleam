import gleam/dynamic/decode

pub type Health {
  Health(ok: Bool, db: String, service: String)
}

pub fn decoder() -> decode.Decoder(Health) {
  use ok <- decode.field("ok", decode.bool)
  use db <- decode.field("db", decode.string)
  use service <- decode.field("service", decode.string)
  decode.success(Health(ok:, db:, service:))
}
