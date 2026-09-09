import application/dependencies

import gleam/http/request
import gleam/http/response
import gleam/option
import mist
import ratelimit/limiter
import transport/http/middleware/security_headers
import transport/http/protocol/mist_errors
import transport/transport_context
import transport/transport_security
import transport/websocket/router

pub fn handle(
  http_request: request.Request(mist.Connection),
  dependencies: dependencies.Dependencies,
  http_handler: fn(request.Request(mist.Connection)) ->
    response.Response(mist.ResponseData),
) -> response.Response(mist.ResponseData) {
  let context = transport_context.new()
  let result = case
    transport_security.allows(
      http_request,
      dependencies.config.transport,
      dependencies.config.environment,
    )
  {
    True -> rate_limit_and_dispatch(http_request, dependencies, http_handler)
    False -> mist_errors.insecure_transport()
  }
  security_headers.handle_mist(result, dependencies.config.transport, context)
}

fn rate_limit_and_dispatch(
  http_request: request.Request(mist.Connection),
  dependencies: dependencies.Dependencies,
  http_handler: fn(request.Request(mist.Connection)) ->
    response.Response(mist.ResponseData),
) -> response.Response(mist.ResponseData) {
  case peer_ip(http_request) {
    option.None -> dispatch(http_request, dependencies, http_handler)
    option.Some(ip) ->
      case limiter.check_http(dependencies.rate_limiter, ip) {
        Ok(Nil) -> dispatch(http_request, dependencies, http_handler)
        Error(limiter.RateLimited(_)) ->
          mist_errors.too_many_requests(transport_context.new())
        Error(limiter.ConnectionsFull) -> mist_errors.service_unavailable()
      }
  }
}

fn dispatch(
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

fn peer_ip(request: request.Request(mist.Connection)) -> option.Option(String) {
  case mist.get_connection_info(request.body) {
    Ok(info) -> option.Some(mist.ip_address_to_string(info.ip_address))
    Error(_) -> option.None
  }
}
