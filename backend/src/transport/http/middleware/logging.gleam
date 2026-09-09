import gleam/http
import gleam/int
import gleam/time/timestamp
import logging
import observability/logger
import transport/http/protocol/status
import transport/transport_context
import wisp

pub fn handle(
  request: wisp.Request,
  context: transport_context.TransportContext,
  next: fn() -> wisp.Response,
) -> wisp.Response {
  let started_at = timestamp.system_time()
  let response = next()
  let duration_ms = elapsed_milliseconds(started_at, timestamp.system_time())
  let level = case response.status >= status.internal_server_error {
    True -> logging.Error
    False -> logging.Info
  }

  logger.write(level, "http_request_completed", [
    #("transport", "http"),
    #("request_id", transport_context.request_id(context)),
    #("method", http.method_to_string(request.method)),
    #("path", request.path),
    #("status", int.to_string(response.status)),
    #("duration_ms", int.to_string(duration_ms)),
  ])
  response
}

fn elapsed_milliseconds(
  started: timestamp.Timestamp,
  finished: timestamp.Timestamp,
) -> Int {
  let #(seconds, nanoseconds) =
    timestamp.to_unix_seconds_and_nanoseconds(finished)
  let #(started_seconds, started_nanoseconds) =
    timestamp.to_unix_seconds_and_nanoseconds(started)
  let total_nanoseconds =
    { seconds - started_seconds }
    * 1_000_000_000
    + nanoseconds
    - started_nanoseconds
  total_nanoseconds / 1_000_000
}
