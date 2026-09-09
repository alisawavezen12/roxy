import dependencies
import gleam/http
import gleam/http/request as http_request
import gleam/list
import gleam/option
import gleam/string
import http/handlers/health
import http/middleware/cors
import http/middleware/error_handler
import http/middleware/logging
import http/protocol/limits
import http/protocol/route_errors as errors
import http/request_context
import wisp

type Body {
  NoBody
  Json
  Multipart
}

type Access {
  Public
  Authenticated
  Permission(String)
}

type Route {
  Route(
    path: String,
    methods: List(http.Method),
    body: Body,
    access: Access,
    handler: fn(dependencies.Dependencies, request_context.RequestContext) ->
      wisp.Response,
  )
}

const routes = [
  Route(
    path: "/health",
    methods: [http.Get],
    body: NoBody,
    access: Public,
    handler: health.handle,
  ),
]

pub fn handle(
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
) -> wisp.Response {
  let context = request_context.new()
  let request =
    request
    |> wisp.set_max_body_size(limits.max_body_size)
    |> wisp.set_max_files_size(limits.max_files_size)
  let response =
    logging.handle(request, context, fn() {
      cors.handle(request, dependencies.config.cors, context, fn() {
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
  request_context.add_request_id(response, context)
}

fn dispatch(
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: request_context.RequestContext,
) -> Result(wisp.Response, errors.Error) {
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
  context: request_context.RequestContext,
) -> Result(wisp.Response, errors.Error) {
  case route.access {
    Public -> check_body(route, request, dependencies, context)
    Authenticated -> Error(errors.Unauthorized)
    Permission(_) -> Error(errors.Forbidden)
  }
}

fn check_body(
  route: Route,
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
  context: request_context.RequestContext,
) -> Result(wisp.Response, errors.Error) {
  case route.body {
    NoBody -> Ok(route.handler(dependencies, context))
    Json ->
      case http_request.get_header(request, "content-type") {
        Ok(content_type) ->
          case string.starts_with(content_type, "application/json") {
            True -> Ok(route.handler(dependencies, context))
            False -> Error(errors.UnsupportedMediaType)
          }
        Error(_) -> Error(errors.UnsupportedMediaType)
      }
    Multipart ->
      case http_request.get_header(request, "content-type") {
        Ok(content_type) ->
          case string.starts_with(content_type, "multipart/form-data") {
            True -> Ok(route.handler(dependencies, context))
            False -> Error(errors.UnsupportedMediaType)
          }
        Error(_) -> Error(errors.UnsupportedMediaType)
      }
  }
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
