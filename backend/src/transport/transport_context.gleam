import application/access
import gleam/bit_array
import gleam/crypto
import gleam/option.{type Option}
import observability/metrics

pub type TransportContext {
  TransportContext(
    request_id: String,
    metrics: metrics.Metrics,
    principal: Option(access.Principal),
  )
}

pub fn new() -> TransportContext {
  TransportContext(
    request_id: "req_" <> random_id(),
    metrics: metrics.disabled(),
    principal: option.None,
  )
}

pub fn new_with(metrics: metrics.Metrics) -> TransportContext {
  TransportContext(
    request_id: "req_" <> random_id(),
    metrics:,
    principal: option.None,
  )
}

pub fn request_id(context: TransportContext) -> String {
  context.request_id
}

pub fn with_principal(
  context: TransportContext,
  principal: Option(access.Principal),
) -> TransportContext {
  TransportContext(..context, principal:)
}

pub fn principal(context: TransportContext) -> Option(access.Principal) {
  context.principal
}

fn random_id() -> String {
  crypto.strong_random_bytes(12)
  |> bit_array.base64_url_encode(False)
}
