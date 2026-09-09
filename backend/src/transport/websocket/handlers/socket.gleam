import application/access
import application/dependencies
import exception
import gleam/http/request
import gleam/http/response
import gleam/option
import mist
import observability/logger
import transport/websocket/connection/context as connection_context
import transport/websocket/protocol/limits

pub type State {
  State(context: connection_context.ConnectionContext)
}

pub fn handle(
  _dependencies: dependencies.Dependencies,
  context: connection_context.ConnectionContext,
  request: request.Request(mist.Connection),
) -> response.Response(mist.ResponseData) {
  mist.websocket(
    request:,
    on_init: fn(_connection) {
      log_connected(context)
      #(State(context:), option.None)
    },
    handler: handle_message,
    on_close: fn(state) { log_closed(state.context) },
  )
}

fn handle_message(
  state: State,
  message: mist.WebsocketMessage(Nil),
  connection: mist.WebsocketConnection,
) -> mist.Next(State, Nil) {
  case exception.rescue(fn() { dispatch_message(state, message, connection) }) {
    Ok(next) -> next
    Error(_) -> {
      log_error(state.context, "handler_crashed")
      mist.stop_abnormal("WebSocket handler crashed")
    }
  }
}

fn dispatch_message(
  state: State,
  message: mist.WebsocketMessage(Nil),
  connection: mist.WebsocketConnection,
) -> mist.Next(State, Nil) {
  case message {
    mist.Text(message) -> handle_text(state, message, connection)
    mist.Binary(message) -> handle_binary(state, message, connection)
    mist.Closed | mist.Shutdown -> mist.stop()
    mist.Custom(_) -> mist.continue(state)
  }
}

fn handle_text(
  state: State,
  message: String,
  connection: mist.WebsocketConnection,
) -> mist.Next(State, Nil) {
  case limits.text_within_limit(message) {
    False -> message_too_large(state)
    True ->
      case mist.send_text_frame(connection, message) {
        Ok(Nil) -> mist.continue(state)
        Error(_) -> send_failed(state)
      }
  }
}

fn handle_binary(
  state: State,
  message: BitArray,
  connection: mist.WebsocketConnection,
) -> mist.Next(State, Nil) {
  case limits.binary_within_limit(message) {
    False -> message_too_large(state)
    True ->
      case mist.send_binary_frame(connection, message) {
        Ok(Nil) -> mist.continue(state)
        Error(_) -> send_failed(state)
      }
  }
}

fn message_too_large(state: State) -> mist.Next(State, Nil) {
  log_error(state.context, "message_too_large")
  mist.stop_abnormal("message too large")
}

fn send_failed(state: State) -> mist.Next(State, Nil) {
  log_error(state.context, "send_failed")
  mist.stop_abnormal("failed to send WebSocket message")
}

fn log_connected(context: connection_context.ConnectionContext) -> Nil {
  logger.info("websocket_connected", context_fields(context))
}

fn log_closed(context: connection_context.ConnectionContext) -> Nil {
  logger.info("websocket_closed", context_fields(context))
}

fn log_error(
  context: connection_context.ConnectionContext,
  reason: String,
) -> Nil {
  logger.error("websocket_error", [
    #("reason", reason),
    ..context_fields(context)
  ])
}

fn context_fields(
  context: connection_context.ConnectionContext,
) -> List(logger.Field) {
  let fields = [
    #("transport", "websocket"),
    #("connection_id", context.connection_id),
    #("request_id", context.request_id),
  ]
  case access.user_id(context.principal) {
    option.Some(user_id) -> [#("user_id", user_id), ..fields]
    option.None -> fields
  }
}
