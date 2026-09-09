import gleam/int
import gleam/list
import gleam/string
import gleam/time/timestamp
import logging

pub type Field =
  #(String, String)

pub fn info(event: String, fields: List(Field)) -> Nil {
  write(logging.Info, event, fields)
}

pub fn error(event: String, fields: List(Field)) -> Nil {
  write(logging.Error, event, fields)
}

pub fn write(
  level: logging.LogLevel,
  event: String,
  fields: List(Field),
) -> Nil {
  let timestamp = timestamp.system_time()
  let #(seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(timestamp)
  let fields = [
    #("timestamp", int.to_string(seconds)),
    #("event", event),
    ..fields
  ]

  let message =
    fields
    |> list.map(fn(field) { field.0 <> "=" <> encode(field.1) })
    |> string.join(" ")
  logging.log(level, message)
}

fn encode(value: String) -> String {
  case string.contains(value, " ") {
    True -> string.inspect(value)
    False -> value
  }
}
