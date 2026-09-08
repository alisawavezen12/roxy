import gleam/http
import gleam/list
import gleam/option
import http/handlers/health
import http/handlers/not_found
import http/protocol/responses
import wisp

type Route {
  Route(
    path: String,
    methods: List(http.Method),
    handler: fn() -> wisp.Response,
  )
}

const routes = [
  Route(path: "/health", methods: [http.Get], handler: health.handle),
]

pub fn handle(request: wisp.Request) -> wisp.Response {
  case find_route(request.path, routes) {
    option.Some(route) -> {
      case list.contains(route.methods, request.method) {
        True -> route.handler()
        False -> responses.method_not_allowed(route.methods)
      }
    }
    option.None -> not_found.handle()
  }
}

fn find_route(path: String, routes: List(Route)) -> option.Option(Route) {
  case routes {
    [] -> option.None
    [route, ..] if route.path == path -> option.Some(route)
    [_, ..rest] -> find_route(path, rest)
  }
}
