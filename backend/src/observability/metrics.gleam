import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/supervision

const process_name = "roxy_metrics"

type Message {
  Record(Metric)
  Read(process.Subject(Snapshot))
}

pub type Metric {
  HttpRequestCompleted(status: Int, duration_ms: Int)
  WebsocketHandshake(status: Int, duration_ms: Int)
  WebsocketConnected
  WebsocketClosed
  WebsocketMessageRateLimited
  WebsocketMessageTooLarge
  SessionMissing
  SessionInvalid
  SessionStoreFailed
  DbProbeFailed
  SupervisorRestarted
}

pub opaque type Metrics {
  Metrics(subject: process.Subject(Message), name: process.Name(Message))
}

pub type Snapshot {
  Snapshot(
    http_requests: Int,
    http_2xx: Int,
    http_4xx: Int,
    http_5xx: Int,
    http_duration_total_ms: Int,
    websocket_handshakes: Int,
    websocket_connections_active: Int,
    websocket_message_rate_limited: Int,
    websocket_message_too_large: Int,
    session_missing: Int,
    session_invalid: Int,
    session_store_failed: Int,
    db_probe_failed: Int,
    supervisor_restarts: Int,
  )
}

pub fn disabled() -> Metrics {
  Metrics(
    subject: process.new_subject(),
    name: process.new_name("disabled_metrics"),
  )
}

pub fn new_child() -> #(Metrics, supervision.ChildSpecification(Nil)) {
  let name = process.new_name(process_name)
  let metrics = Metrics(subject: process.named_subject(name), name:)
  let child =
    supervision.worker(fn() {
      actor.start(
        actor.new(initial_snapshot())
        |> actor.on_message(handle_message)
        |> actor.named(name),
      )
      |> result_map(fn(_) { Nil })
    })
  #(metrics, child)
}

pub fn record(metrics: Metrics, metric: Metric) -> Nil {
  process.send(metrics.subject, Record(metric))
}

pub fn snapshot(metrics: Metrics) -> Snapshot {
  actor.call(metrics.subject, 100, Read)
}

fn handle_message(
  state: Snapshot,
  message: Message,
) -> actor.Next(Snapshot, Message) {
  case message {
    Record(metric) -> actor.continue(record_metric(state, metric))
    Read(reply) -> {
      process.send(reply, state)
      actor.continue(state)
    }
  }
}

fn initial_snapshot() -> Snapshot {
  Snapshot(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

fn record_metric(state: Snapshot, metric: Metric) -> Snapshot {
  case metric {
    HttpRequestCompleted(status, duration_ms) ->
      Snapshot(
        ..state,
        http_requests: state.http_requests + 1,
        http_2xx: increment_if(state.http_2xx, status >= 200 && status < 300),
        http_4xx: increment_if(state.http_4xx, status >= 400 && status < 500),
        http_5xx: increment_if(state.http_5xx, status >= 500),
        http_duration_total_ms: state.http_duration_total_ms + duration_ms,
      )
    WebsocketHandshake(_, _) ->
      Snapshot(..state, websocket_handshakes: state.websocket_handshakes + 1)
    WebsocketConnected ->
      Snapshot(
        ..state,
        websocket_connections_active: state.websocket_connections_active + 1,
      )
    WebsocketClosed ->
      Snapshot(
        ..state,
        websocket_connections_active: max_zero(
          state.websocket_connections_active - 1,
        ),
      )
    WebsocketMessageRateLimited ->
      Snapshot(
        ..state,
        websocket_message_rate_limited: state.websocket_message_rate_limited + 1,
      )
    WebsocketMessageTooLarge ->
      Snapshot(
        ..state,
        websocket_message_too_large: state.websocket_message_too_large + 1,
      )
    SessionMissing ->
      Snapshot(..state, session_missing: state.session_missing + 1)
    SessionInvalid ->
      Snapshot(..state, session_invalid: state.session_invalid + 1)
    SessionStoreFailed ->
      Snapshot(..state, session_store_failed: state.session_store_failed + 1)
    DbProbeFailed ->
      Snapshot(..state, db_probe_failed: state.db_probe_failed + 1)
    SupervisorRestarted ->
      Snapshot(..state, supervisor_restarts: state.supervisor_restarts + 1)
  }
}

fn increment_if(value: Int, condition: Bool) -> Int {
  case condition {
    True -> value + 1
    False -> value
  }
}

fn max_zero(value: Int) -> Int {
  case value < 0 {
    True -> 0
    False -> value
  }
}

fn result_map(
  result: Result(actor.Started(data), actor.StartError),
  transform: fn(data) -> value,
) -> Result(actor.Started(value), actor.StartError) {
  case result {
    Ok(started) -> Ok(actor.Started(started.pid, transform(started.data)))
    Error(error) -> Error(error)
  }
}
