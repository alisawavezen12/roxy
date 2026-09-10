import config/origins
import config/transport
import gleam/http
import gleam/http/request
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{type Uri, Uri}
import logging
import observability/logger
import observability/metrics
import transport/http/protocol/http_errors
import transport/transport_context
import wisp

pub fn handle(
  http_request: wisp.Request,
  origins_config: origins.OriginsConfig,
  transport_config: transport.TransportConfig,
  context: transport_context.TransportContext,
  next: fn(wisp.Request) -> Result(wisp.Response, http_errors.HttpError),
) -> Result(wisp.Response, http_errors.HttpError) {
  case safe_method(http_request.method) {
    True -> next(http_request)
    False -> protect_unsafe_request(
      http_request,
      origins_config,
      transport_config,
      context,
      next,
    )
  }
}

fn protect_unsafe_request(
  http_request: wisp.Request,
  origins_config: origins.OriginsConfig,
  transport_config: transport.TransportConfig,
  context: transport_context.TransportContext,
  next: fn(wisp.Request) -> Result(wisp.Response, http_errors.HttpError),
) -> Result(wisp.Response, http_errors.HttpError) {
  case request_origin(http_request) {
    option.None -> next(without_cookies(http_request))
    option.Some(Error(_)) -> reject(context, "invalid_origin")
    option.Some(Ok(origin)) ->
      case allowed_origin(origin, origins_config, transport_config) {
        True -> next(http_request)
        False -> reject(context, "origin_not_allowed")
      }
  }
}

fn safe_method(method: http.Method) -> Bool {
  case method {
    http.Get | http.Head | http.Options -> True
    _ -> False
  }
}

fn request_origin(
  http_request: wisp.Request,
) -> option.Option(Result(String, Nil)) {
  case request.get_header(http_request, "origin") {
    Ok(origin) -> option.Some(normalize_origin_header(origin))
    Error(_) ->
      case request.get_header(http_request, "referer") {
        Ok(referer) -> option.Some(normalize_referer(referer))
        Error(_) -> option.None
      }
  }
}

fn normalize_origin_header(value: String) -> Result(String, Nil) {
  use parsed <- result.try(parse_http_uri(value))
  case parsed.path, parsed.query, parsed.fragment {
    "", option.None, option.None -> normalized_origin(parsed)
    _, _, _ -> Error(Nil)
  }
}

fn normalize_referer(value: String) -> Result(String, Nil) {
  use parsed <- result.try(parse_http_uri(value))
  normalized_origin(parsed)
}

fn parse_http_uri(value: String) -> Result(Uri, Nil) {
  case uri.parse(string.trim(value)) {
    Ok(Uri(
      scheme: option.Some(scheme),
      userinfo: option.None,
      host: option.Some(host),
      ..,
    ) as parsed)
      if host != ""
    -> {
      case string.lowercase(scheme) {
        "http" | "https" -> Ok(parsed)
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn normalized_origin(parsed: Uri) -> Result(String, Nil) {
  parsed
  |> uri.origin
  |> result.map(string.lowercase)
}

fn allowed_origin(
  origin: String,
  origins_config: origins.OriginsConfig,
  transport_config: transport.TransportConfig,
) -> Bool {
  let public_origin = normalize_referer(transport_config.public_base_url)
  list.contains(origins_config.allowed, origin)
  || public_origin == Ok(origin)
}

fn without_cookies(http_request: wisp.Request) -> wisp.Request {
  let headers = list.filter(http_request.headers, fn(header) {
    header.0 != "cookie"
  })
  request.Request(..http_request, headers:)
}

fn reject(
  context: transport_context.TransportContext,
  reason: String,
) -> Result(wisp.Response, http_errors.HttpError) {
  metrics.record(context.metrics, metrics.CsrfRejected)
  logger.write(logging.Warning, "csrf_rejected", [
    #("request_id", transport_context.request_id(context)),
    #("reason", reason),
  ])
  Error(http_errors.CsrfForbidden)
}
