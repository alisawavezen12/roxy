import gleam/erlang/process

import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import ratelimit/clock
import ratelimit/policy

pub type Key {
  HttpIp(String)
  WebsocketConnection(String)
}

type Bucket {
  Bucket(count: Int, started_at: Int, window_ms: Int)
}

type State {
  State(buckets: List(#(Key, Bucket)), websocket_connections: Int)
}

type Message {
  Check(
    key: Key,
    limit: Int,
    window_ms: Int,
    now: Int,
    reply: process.Subject(Result(Nil, Rejection)),
  )
  OpenWebsocket(process.Subject(Result(Nil, Rejection)))
  CloseWebsocket
}

pub type Rejection {
  RateLimited(retry_after_ms: Int)
  ConnectionsFull
}

pub opaque type Limiter {
  Limiter(subject: process.Subject(Message), name: process.Name(Message))
}

fn new() -> Limiter {
  let name = process.new_name("roxy_rate_limiter")
  Limiter(subject: process.named_subject(name), name:)
}

pub fn new_child() -> #(Limiter, supervision.ChildSpecification(Nil)) {
  let limiter = new()
  #(limiter, child(limiter))
}

fn child(limiter: Limiter) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() {
    actor.start(builder(limiter))
    |> result_map(fn(_) { Nil })
  })
}

pub fn check_http(limiter: Limiter, ip: String) -> Result(Nil, Rejection) {
  check(
    limiter,
    HttpIp(ip),
    policy.http_requests_per_window,
    policy.http_window_ms,
  )
}

pub fn check_websocket_message(
  limiter: Limiter,
  connection_id: String,
) -> Result(Nil, Rejection) {
  check(
    limiter,
    WebsocketConnection(connection_id),
    policy.websocket_messages_per_window,
    policy.websocket_window_ms,
  )
}

pub fn open_websocket(limiter: Limiter) -> Result(Nil, Rejection) {
  actor.call(limiter.subject, policy.limiter_call_timeout_ms, fn(reply) {
    OpenWebsocket(reply)
  })
}

pub fn close_websocket(limiter: Limiter) -> Nil {
  actor.send(limiter.subject, CloseWebsocket)
}

fn builder(
  limiter: Limiter,
) -> actor.Builder(State, Message, process.Subject(Message)) {
  actor.new(State(buckets: [], websocket_connections: 0))
  |> actor.on_message(handle_message)
  |> actor.named(limiter.name)
}

fn check(
  limiter: Limiter,
  key: Key,
  limit: Int,
  window_ms: Int,
) -> Result(Nil, Rejection) {
  actor.call(limiter.subject, policy.limiter_call_timeout_ms, fn(reply) {
    Check(key:, limit:, window_ms:, now: clock.now(), reply:)
  })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Check(key:, limit:, window_ms:, now:, reply:) -> {
      let #(buckets, result) =
        check_bucket(state.buckets, key, limit, window_ms, now)
      process.send(reply, result)
      actor.continue(State(..state, buckets: buckets))
    }
    OpenWebsocket(reply) ->
      case state.websocket_connections >= policy.max_websocket_connections {
        True -> {
          process.send(reply, Error(ConnectionsFull))
          actor.continue(state)
        }
        False -> {
          process.send(reply, Ok(Nil))
          actor.continue(
            State(
              ..state,
              websocket_connections: state.websocket_connections + 1,
            ),
          )
        }
      }
    CloseWebsocket ->
      actor.continue(
        State(
          ..state,
          websocket_connections: case state.websocket_connections > 0 {
            True -> state.websocket_connections - 1
            False -> 0
          },
        ),
      )
  }
}

fn check_bucket(
  buckets: List(#(Key, Bucket)),
  key: Key,
  limit: Int,
  window_ms: Int,
  now: Int,
) -> #(List(#(Key, Bucket)), Result(Nil, Rejection)) {
  let buckets = cleanup(buckets, now)
  case find_bucket(buckets, key) {
    option.None -> #(
      [#(key, Bucket(count: 1, started_at: now, window_ms:)), ..buckets],
      Ok(Nil),
    )
    option.Some(bucket) -> {
      let elapsed = now - bucket.started_at
      case elapsed >= window_ms {
        True -> #(
          replace_bucket(
            buckets,
            key,
            Bucket(count: 1, started_at: now, window_ms:),
          ),
          Ok(Nil),
        )
        False if bucket.count < limit -> #(
          replace_bucket(
            buckets,
            key,
            Bucket(..bucket, count: bucket.count + 1),
          ),
          Ok(Nil),
        )
        False -> #(buckets, Error(RateLimited(window_ms - elapsed)))
      }
    }
  }
}

fn cleanup(buckets: List(#(Key, Bucket)), now: Int) -> List(#(Key, Bucket)) {
  list.filter(buckets, fn(entry) {
    let bucket = entry.1
    now - bucket.started_at < bucket.window_ms
  })
}

fn find_bucket(
  buckets: List(#(Key, Bucket)),
  key: Key,
) -> option.Option(Bucket) {
  case buckets {
    [] -> option.None
    [#(same_key, bucket), ..] if same_key == key -> option.Some(bucket)
    [_, ..rest] -> find_bucket(rest, key)
  }
}

fn replace_bucket(
  buckets: List(#(Key, Bucket)),
  key: Key,
  replacement: Bucket,
) -> List(#(Key, Bucket)) {
  case buckets {
    [] -> [#(key, replacement)]
    [#(same_key, _), ..rest] if same_key == key -> [#(key, replacement), ..rest]
    [entry, ..rest] -> [entry, ..replace_bucket(rest, key, replacement)]
  }
}

fn result_map(
  result: Result(actor.Started(data), actor.StartError),
  transform: fn(data) -> result,
) -> Result(actor.Started(result), actor.StartError) {
  case result {
    Ok(started) -> Ok(actor.Started(started.pid, transform(started.data)))
    Error(error) -> Error(error)
  }
}
