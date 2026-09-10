import gleam/otp/static_supervisor as supervisor
import gleeunit/should
import observability/metrics

pub fn metrics_count_http_statuses_and_latency_test() {
  let #(metrics, child) = metrics.new_child()
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start

  metrics.record(metrics, metrics.HttpRequestCompleted(200, 12))
  metrics.record(metrics, metrics.HttpRequestCompleted(404, 8))
  metrics.record(metrics, metrics.HttpRequestCompleted(500, 20))

  let snapshot = metrics.snapshot(metrics)
  snapshot.http_requests
  |> should.equal(3)
  snapshot.http_2xx
  |> should.equal(1)
  snapshot.http_4xx
  |> should.equal(1)
  snapshot.http_5xx
  |> should.equal(1)
  snapshot.http_duration_total_ms
  |> should.equal(40)
}

pub fn metrics_track_websocket_connections_and_events_test() {
  let #(metrics, child) = metrics.new_child()
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child)
    |> supervisor.start

  metrics.record(metrics, metrics.WebsocketConnected)
  metrics.record(metrics, metrics.WebsocketMessageTooLarge)
  metrics.record(metrics, metrics.WebsocketMessageRateLimited)
  metrics.record(metrics, metrics.WebsocketClosed)
  metrics.record(metrics, metrics.SessionMissing)
  metrics.record(metrics, metrics.SessionInvalid)
  metrics.record(metrics, metrics.SessionStoreFailed)
  metrics.record(metrics, metrics.DbProbeFailed)

  let snapshot = metrics.snapshot(metrics)
  snapshot.websocket_connections_active
  |> should.equal(0)
  snapshot.websocket_message_too_large
  |> should.equal(1)
  snapshot.websocket_message_rate_limited
  |> should.equal(1)
  snapshot.session_missing
  |> should.equal(1)
  snapshot.session_invalid
  |> should.equal(1)
  snapshot.session_store_failed
  |> should.equal(1)
  snapshot.db_probe_failed
  |> should.equal(1)
}
