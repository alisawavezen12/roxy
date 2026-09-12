import gleam/dynamic/decode

pub type ApiError {
  ApiError(code: String, message: String, request_id: String)
}

type ApiErrorPayload {
  ApiErrorPayload(code: String, message: String, request_id: String)
}

pub const internal_error_code = "internal"

pub const internal_error_message = "Internal server error"

pub const not_found_code = "not_found"

pub const not_found_message = "Not found"

pub const method_not_allowed_code = "method_not_allowed"

pub const method_not_allowed_message = "Method not allowed"

pub const unsupported_media_type_code = "unsupported_media_type"

pub const unsupported_media_type_message = "Unsupported media type"

pub const invalid_body_code = "invalid_body"

pub const invalid_body_message = "Invalid request body"

pub const payload_too_large_code = "payload_too_large"

pub const payload_too_large_message = "Request body is too large"

pub const rate_limited_code = "rate_limited"

pub const rate_limited_message = "Too many requests"

pub const csrf_forbidden_code = "csrf_forbidden"

pub const csrf_forbidden_message = "Request origin is not allowed"

pub const cors_forbidden_code = "cors_forbidden"

pub const cors_forbidden_message = "CORS request is not allowed"

pub const unauthorized_code = "unauthorized"

pub const unauthorized_message = "Unauthorized"

pub const forbidden_code = "forbidden"

pub const forbidden_message = "Forbidden"

pub const invalid_handshake_code = "invalid_input"

pub const invalid_handshake_message = "Invalid WebSocket handshake"

pub fn decoder() -> decode.Decoder(ApiError) {
  use payload <- decode.field("error", payload_decoder())
  let ApiErrorPayload(code:, message:, request_id:) = payload
  decode.success(ApiError(code:, message:, request_id:))
}

fn payload_decoder() -> decode.Decoder(ApiErrorPayload) {
  use code <- decode.field("code", decode.string)
  use message <- decode.field("message", decode.string)
  use request_id <- decode.field("request_id", decode.string)
  decode.success(ApiErrorPayload(code:, message:, request_id:))
}
