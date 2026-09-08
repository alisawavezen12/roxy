import gleam/http
import gleam/int
import gleam/string
import gleam/time/timestamp
import http/protocol/status
import http/request_context
import logging
import wisp

pub fn handle(
  request: wisp.Request,
  context: request_context.RequestContext,
  next: fn() -> wisp.Response,
) -> wisp.Response {
  let started_at = timestamp.system_time()
  let response = next()
  let duration_ms = elapsed_milliseconds(started_at, timestamp.system_time())
  let level = case response.status >= status.internal_server_error {
    True -> logging.Error
    False -> logging.Info
  }

  logging.log(
    level,
    string.concat([
      "timestamp=",
      int.to_string(timestamp_seconds(timestamp.system_time())),
      " request_id=",
      request_context.request_id(context),
      " method=",
      http.method_to_string(request.method),
      " path=",
      request.path,
      " status=",
      int.to_string(response.status),
      " duration_ms=",
      int.to_string(duration_ms),
    ]),
  )
  response
}

fn timestamp_seconds(timestamp: timestamp.Timestamp) -> Int {
  let #(seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(timestamp)
  seconds
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
