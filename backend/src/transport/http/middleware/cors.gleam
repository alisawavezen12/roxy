import config/origins
import gleam/http
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/list
import gleam/string
import transport/http/protocol/api_errors
import transport/http/protocol/cors as cors_policy
import transport/http/protocol/status
import transport/protocol/messages
import transport/transport_context
import wisp

pub fn handle(
  request: wisp.Request,
  config: origins.OriginsConfig,
  context: transport_context.TransportContext,
  next: fn() -> wisp.Response,
) -> wisp.Response {
  case http_request.get_header(request, "origin") {
    Error(_) -> next()
    Ok(origin) -> handle_cross_origin(request, config, context, origin, next)
  }
}

fn handle_cross_origin(
  request: wisp.Request,
  config: origins.OriginsConfig,
  context: transport_context.TransportContext,
  origin: String,
  next: fn() -> wisp.Response,
) -> wisp.Response {
  case is_preflight(request) {
    True -> preflight_response(request, config, context, origin)
    False -> {
      let response = next()
      case list.contains(config.allowed, string.lowercase(origin)) {
        True -> add_origin_headers(response, origin)
        False -> response
      }
    }
  }
}

fn is_preflight(request: wisp.Request) -> Bool {
  request.method == http.Options
  && {
    case http_request.get_header(request, "access-control-request-method") {
      Ok(_) -> True
      Error(_) -> False
    }
  }
}

fn preflight_response(
  request: wisp.Request,
  config: origins.OriginsConfig,
  context: transport_context.TransportContext,
  origin: String,
) -> wisp.Response {
  case
    list.contains(config.allowed, string.lowercase(origin))
    && requested_method_is_allowed(request, cors_policy.allowed_methods)
    && requested_headers_are_allowed(request, cors_policy.allowed_headers)
  {
    True ->
      wisp.no_content()
      |> add_origin_headers(origin)
      |> add_preflight_vary
      |> wisp.set_header(
        "access-control-allow-methods",
        methods_header(cors_policy.allowed_methods),
      )
      |> wisp.set_header(
        "access-control-allow-headers",
        string.join(cors_policy.allowed_headers, ", "),
      )
    False ->
      api_errors.response(
        status.forbidden,
        messages.cors_forbidden_code,
        messages.cors_forbidden_message,
        context,
      )
  }
}

fn requested_method_is_allowed(
  request: wisp.Request,
  allowed_methods: List(http.Method),
) -> Bool {
  case http_request.get_header(request, "access-control-request-method") {
    Ok(method) ->
      case http.parse_method(method) {
        Ok(method) -> list.contains(allowed_methods, method)
        Error(_) -> False
      }
    Error(_) -> False
  }
}

fn requested_headers_are_allowed(
  request: wisp.Request,
  allowed_headers: List(String),
) -> Bool {
  case http_request.get_header(request, "access-control-request-headers") {
    Error(_) -> True
    Ok(value) ->
      value
      |> string.split(",")
      |> list.all(fn(header) {
        let header = string.trim(header)
        header != ""
        && list.any(allowed_headers, fn(allowed) {
          string.lowercase(allowed) == string.lowercase(header)
        })
      })
  }
}

fn methods_header(methods: List(http.Method)) -> String {
  methods
  |> list.map(http.method_to_string)
  |> string.join(", ")
}

fn add_preflight_vary(response: wisp.Response) -> wisp.Response {
  wisp.set_header(
    response,
    "vary",
    "Origin, Access-Control-Request-Method, Access-Control-Request-Headers",
  )
}

fn add_origin_headers(
  response: wisp.Response,
  origin: String,
) -> wisp.Response {
  response
  |> wisp.set_header("access-control-allow-origin", origin)
  |> wisp.set_header("access-control-allow-credentials", "true")
  |> add_vary_origin
}

fn add_vary_origin(response: wisp.Response) -> wisp.Response {
  case http_response.get_header(response, "vary") {
    Error(_) -> wisp.set_header(response, "vary", "Origin")
    Ok(value) -> {
      let varies_by_origin =
        value
        |> string.split(",")
        |> list.any(fn(item) {
          let item = string.trim(item)
          item == "*" || string.lowercase(item) == "origin"
        })

      case varies_by_origin {
        True -> response
        False -> wisp.set_header(response, "vary", value <> ", Origin")
      }
    }
  }
}
