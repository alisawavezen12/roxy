import gleam/bit_array
import gleam/crypto

pub type TransportContext {
  TransportContext(request_id: String)
}

pub fn new() -> TransportContext {
  TransportContext(request_id: "req_" <> random_id())
}

pub fn request_id(context: TransportContext) -> String {
  context.request_id
}

fn random_id() -> String {
  crypto.strong_random_bytes(12)
  |> bit_array.base64_url_encode(False)
}
