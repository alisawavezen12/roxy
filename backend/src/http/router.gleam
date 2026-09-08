import dependencies
import errors
import gleam/http
import gleam/list
import gleam/option
import http/handlers/health
import http/middleware/error_handler
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
    handler: fn(dependencies.Dependencies) -> wisp.Response,
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
  error_handler.handle(request, fn() { dispatch(request, dependencies) })
}

fn dispatch(
  request: wisp.Request,
  dependencies: dependencies.Dependencies,
) -> Result(wisp.Response, errors.Error) {
  case find_route(request.path, routes) {
    option.Some(route) -> {
      case list.contains(route.methods, request.method) {
        True -> authorize(route.access, route.handler, dependencies)
        False -> Error(errors.MethodNotAllowed(route.methods))
      }
    }
    option.None -> Error(errors.NotFound)
  }
}

fn authorize(
  access: Access,
  handler: fn(dependencies.Dependencies) -> wisp.Response,
  dependencies: dependencies.Dependencies,
) -> Result(wisp.Response, errors.Error) {
  case access {
    Public -> Ok(handler(dependencies))
    Authenticated -> Error(errors.Unauthorized)
    Permission(_) -> Error(errors.Forbidden)
  }
}

fn find_route(path: String, routes: List(Route)) -> option.Option(Route) {
  case routes {
    [] -> option.None
    [route, ..] if route.path == path -> option.Some(route)
    [_, ..rest] -> find_route(path, rest)
  }
}
