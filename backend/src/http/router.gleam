import dependencies
import errors
import gleam/http
import gleam/list
import gleam/option
import http/handlers/health
import http/middleware/error_handler
import http/protocol/limits
import http/request_context
import wisp

type Access {
  Public
  Authenticated
  Permission(String)
}

type Route {
  Route(
    path: String,
    methods: List(http.Method),
    access: Access,
    handler: fn(dependencies.Dependencies, request_context.RequestContext) ->
      wisp.Response,
  )
}

const routes = [
  Route(
    path: "/health",
    methods: [http.Get],
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
    error_handler.handle(request, fn() {
      Ok(
        wisp.handle_head(request, fn(request) {
          case dispatch(request, dependencies, context) {
            Ok(response) -> response
            Error(error) -> error_handler.response(error)
          }
        }),
      )
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
        True -> authorize(route.access, route.handler, dependencies, context)
        False -> Error(errors.MethodNotAllowed(allowed_methods(route.methods)))
      }
    }
    option.None -> Error(errors.NotFound)
  }
}

fn authorize(
  access: Access,
  handler: fn(dependencies.Dependencies, request_context.RequestContext) ->
    wisp.Response,
  dependencies: dependencies.Dependencies,
  context: request_context.RequestContext,
) -> Result(wisp.Response, errors.Error) {
  case access {
    Public -> Ok(handler(dependencies, context))
    Authenticated -> Error(errors.Unauthorized)
    Permission(_) -> Error(errors.Forbidden)
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
