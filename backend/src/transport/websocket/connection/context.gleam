import application/access
import gleam/option.{type Option}
import observability/metrics
import transport/transport_context
import wisp

pub type ConnectionContext {
  ConnectionContext(
    connection_id: String,
    request_id: String,
    principal: Option(access.Principal),
    metrics: metrics.Metrics,
  )
}

pub fn new(
  context: transport_context.TransportContext,
  principal: Option(access.Principal),
) -> ConnectionContext {
  ConnectionContext(
    connection_id: "conn_" <> wisp.random_string(16),
    request_id: transport_context.request_id(context),
    principal:,
    metrics: context.metrics,
  )
}
