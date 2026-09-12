import gleam/bit_array
import gleam/dynamic/decode
import gleam/http/request as http_request
import gleam/json
import gleam/string
import transport/http/middleware/error_handler
import transport/http/protocol/http_errors
import transport/http/protocol/status
import transport/transport_context
import wisp

pub type Contract {
  NoBody
  Json
  Multipart
}

pub type ParsedBody {
  EmptyBody
  JsonBody(String)
  MultipartBody(wisp.FormData)
}

pub fn parse(
  request: wisp.Request,
  contract: Contract,
  context: transport_context.TransportContext,
  next: fn(ParsedBody) -> wisp.Response,
) -> wisp.Response {
  case contract {
    NoBody -> next(EmptyBody)
    Json -> parse_json(request, context, next)
    Multipart -> parse_multipart(request, context, next)
  }
}

fn parse_json(
  request: wisp.Request,
  context: transport_context.TransportContext,
  next: fn(ParsedBody) -> wisp.Response,
) -> wisp.Response {
  case http_request.get_header(request, "content-type") {
    Error(_) ->
      error_handler.response(http_errors.UnsupportedMediaType, context)
    Ok(content_type) ->
      case media_type_is(content_type, "application/json") {
        False ->
          error_handler.response(http_errors.UnsupportedMediaType, context)
        True ->
          case wisp.read_body_bits(request) {
            Error(_) ->
              error_handler.response(http_errors.PayloadTooLarge, context)
            Ok(bits) ->
              case bit_array.to_string(bits) {
                Error(_) ->
                  error_handler.response(http_errors.InvalidBody, context)
                Ok(body) ->
                  case json.parse(body, decode.dynamic) {
                    Ok(_) -> next(JsonBody(body))
                    Error(_) ->
                      error_handler.response(http_errors.InvalidBody, context)
                  }
              }
          }
      }
  }
}

fn parse_multipart(
  request: wisp.Request,
  context: transport_context.TransportContext,
  next: fn(ParsedBody) -> wisp.Response,
) -> wisp.Response {
  case http_request.get_header(request, "content-type") {
    Error(_) ->
      error_handler.response(http_errors.UnsupportedMediaType, context)
    Ok(content_type) ->
      case media_type_is(content_type, "multipart/form-data") {
        False ->
          error_handler.response(http_errors.UnsupportedMediaType, context)
        True ->
          wisp.require_form(request, fn(form) { next(MultipartBody(form)) })
          |> normalize_multipart_response(context)
      }
  }
}

fn normalize_multipart_response(
  response: wisp.Response,
  context: transport_context.TransportContext,
) -> wisp.Response {
  case response.status {
    value if value == status.bad_request ->
      error_handler.response(http_errors.InvalidBody, context)
    value if value == status.payload_too_large ->
      error_handler.response(http_errors.PayloadTooLarge, context)
    value if value == status.unsupported_media_type ->
      error_handler.response(http_errors.UnsupportedMediaType, context)
    _ -> response
  }
}

fn media_type_is(content_type: String, expected: String) -> Bool {
  case string.split(content_type, ";") {
    [media_type, ..] -> string.lowercase(string.trim(media_type)) == expected
    [] -> False
  }
}
