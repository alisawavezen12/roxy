import application/dependencies
import gleam/http/request
import gleam/http/response
import mist
import transport/websocket/router

pub fn handle(
  http_request: request.Request(mist.Connection),
  dependencies: dependencies.Dependencies,
  http_handler: fn(request.Request(mist.Connection)) ->
    response.Response(mist.ResponseData),
) -> response.Response(mist.ResponseData) {
  case router.dispatch(http_request, dependencies) {
    router.NoMatch -> http_handler(http_request)
    router.Matched(response) -> response
  }
}
