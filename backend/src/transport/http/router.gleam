import application/dependencies

import application/access
import gleam/http

import gleam/list
import gleam/option

import transport/http/handlers/health
import transport/http/handlers/readiness
import transport/http/middleware/cors
import transport/http/middleware/error_handler
import transport/http/middleware/logging
import transport/http/middleware/security_headers
import transport/http/protocol/http_errors as errors
import transport/http/protocol/limits
import transport/http/request_body
import transport/http/request_id
import transport/session
import transport/transport_context
import wisp

type Route {
  Route(
    path: String,
    methods: List(http.Method),
    body: request_body.Contract,
    access: access.Access,
    handler: fn(
      dependencies.Dependencies,
      transport_context.TransportContext,
      request_body.ParsedBody,
    ) -> wisp.Response,
  )
}

const routes = [
  Route(
    path: "/health",
    methods: [http.Get],
    body: request_body.NoBody,
    access: access.Public,
    handler: health_route,
  ),
  Route(
    path: "/ready",
    methods: [http.Get],
    body: request_body.NoBody,
    access: access.Public,
    handler: readiness_route,
  ),
]

pub fn handle(
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
) -> wisp.Response {
  let context = transport_context.new_with(dependencies.metrics)
  let request =
    request
    |> wisp.set_max_body_size(limits.max_body_size)
    |> wisp.set_max_files_size(limits.max_files_size)
  let response =
    logging.handle(request, context, fn() {
      cors.handle(request, dependencies.config.origins, context, fn() {
        error_handler.handle(request, context, fn() {
          Ok(
            wisp.handle_head(request, fn(request) {
              case dispatch(request, dependencies, context) {
                Ok(response) -> response
                Error(error) -> error_handler.response(error, context)
              }
            }),
          )
        })
      })
    })
  response
  |> security_headers.handle(dependencies.config.transport)
  |> fn(response) { request_id.add_request_id(response, context) }
}

fn dispatch(
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> Result(wisp.Response, errors.HttpError) {
  case find_route(request.path, routes) {
    option.Some(route) -> {
      case list.contains(route.methods, request.method) {
        True -> authorize(route, request, dependencies, context)
        False -> Error(errors.MethodNotAllowed(allowed_methods(route.methods)))
      }
    }
    option.None -> Error(errors.NotFound)
  }
}

fn authorize(
  route: Route,
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> Result(wisp.Response, errors.HttpError) {
  let principal =
    session.principal(request, dependencies.config.secret_key_base, context)
  case access.authorize(route.access, principal) {
    Ok(_) -> check_body(route, request, dependencies, context)
    Error(access.Unauthenticated) ->
      Error(errors.Access(access.Unauthenticated))
    Error(access.Forbidden) -> Error(errors.Access(access.Forbidden))
  }
}

fn health_route(
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
  _body: request_body.ParsedBody,
) -> wisp.Response {
  health.handle(dependencies, context)
}

fn readiness_route(
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
  _body: request_body.ParsedBody,
) -> wisp.Response {
  readiness.handle(dependencies, context)
}

fn check_body(
  route: Route,
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: transport_context.TransportContext,
) -> Result(wisp.Response, errors.HttpError) {
  let response =
    request_body.parse(request, route.body, context, fn(body) {
      route.handler(dependencies, context, body)
    })
  Ok(response)
}

fn allowed_methods(methods: List(http.Method)) -> List(http.Method) {
  case list.contains(methods, http.Get) {
    True -> [http.Get, http.Head, ..methods_without_get(methods)]
    False -> methods
  }
}

fn methods_without_get(methods: List(http.Method)) -> List(http.Method) {
  list.filter(methods, fn(method) { method != http.Get })
}

fn find_route(path: String, routes: List(Route)) -> option.Option(Route) {
  case routes {
    [] -> option.None
    [route, ..] if route.path == path -> option.Some(route)
    [_, ..rest] -> find_route(path, rest)
  }
}
