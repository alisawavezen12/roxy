import application/access
import application/dependencies
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/option
import gleam/time/timestamp
import logging
import mist
import observability/logger
import observability/metrics
import transport/http/protocol/status
import transport/session
import transport/transport_context
import transport/websocket/connection/context as connection_context
import transport/websocket/handlers/socket
import transport/websocket/handshake/error_response
import transport/websocket/handshake/validation

const nanoseconds_per_second = 1_000_000_000

const nanoseconds_per_millisecond = 1_000_000

pub type Handler =
  fn(
    dependencies.Dependencies,
    connection_context.ConnectionContext,
    request.Request(mist.Connection),
  ) -> response.Response(mist.ResponseData)

pub type Route {
  Route(
    path: String,
    methods: List(http.Method),
    access: access.Access,
    handler: Handler,
  )
}

pub type Match {
  NoMatch
  Matched(response.Response(mist.ResponseData))
}

const routes = [
  Route(
    path: "/ws",
    methods: [http.Get],
    access: access.Public,
    handler: socket.handle,
  ),
]

pub fn dispatch(
  http_request: request.Request(mist.Connection),
  dependencies: dependencies.Dependencies,
) -> Match {
  case find_route(http_request.path, routes) {
    option.None -> NoMatch
    option.Some(route) -> Matched(handle(route, http_request, dependencies))
  }
}

fn handle(
  route: Route,
  http_request: request.Request(mist.Connection),
  dependencies: dependencies.Dependencies,
) -> response.Response(mist.ResponseData) {
  let context = transport_context.new_with(dependencies.metrics)
  let started_at = timestamp.system_time()
  let response = case
    validation.validate(
      http_request,
      route.methods,
      dependencies.config.origins,
    )
  {
    Error(error) -> error_response.response(error, context)
    Ok(Nil) -> {
      let principal = session.principal(http_request, dependencies, context)
      case access.authorize(route.access, principal) {
        Error(access.Unauthenticated) ->
          error_response.response(
            validation.Access(access.Unauthenticated),
            context,
          )
        Error(access.Forbidden) ->
          error_response.response(validation.Access(access.Forbidden), context)
        Ok(principal) ->
          route.handler(
            dependencies,
            connection_context.new(context, principal),
            http_request,
          )
      }
    }
  }

  let response =
    response.set_header(
      response,
      "x-request-id",
      transport_context.request_id(context),
    )
  metrics.record(
    dependencies.metrics,
    metrics.WebsocketHandshake(
      response.status,
      elapsed_milliseconds(started_at),
    ),
  )
  log_handshake(http_request, response, context, started_at)
  response
}

fn log_handshake(
  request: request.Request(mist.Connection),
  response: response.Response(mist.ResponseData),
  context: transport_context.TransportContext,
  started_at: timestamp.Timestamp,
) -> Nil {
  let duration_ms = elapsed_milliseconds(started_at)
  let level = case response.status >= status.internal_server_error {
    True -> logging.Error
    False -> logging.Info
  }
  logger.write(level, "websocket_handshake_completed", [
    #("transport", "websocket"),
    #("request_id", transport_context.request_id(context)),
    #("method", http.method_to_string(request.method)),
    #("path", request.path),
    #("status", int.to_string(response.status)),
    #("duration_ms", int.to_string(duration_ms)),
  ])
}

fn elapsed_milliseconds(started: timestamp.Timestamp) -> Int {
  let #(seconds, nanoseconds) =
    timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
  let #(started_seconds, started_nanoseconds) =
    timestamp.to_unix_seconds_and_nanoseconds(started)
  let total_nanoseconds =
    { seconds - started_seconds }
    * nanoseconds_per_second
    + nanoseconds
    - started_nanoseconds
  total_nanoseconds / nanoseconds_per_millisecond
}

fn find_route(path: String, routes: List(Route)) -> option.Option(Route) {
  case routes {
    [] -> option.None
    [route, ..] if route.path == path -> option.Some(route)
    [_, ..rest] -> find_route(path, rest)
  }
}
