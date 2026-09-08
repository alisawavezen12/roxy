import gleam/bytes_tree
import gleam/http/response as http_response
import mist

pub const text_content_type = "text/plain; charset=utf-8"

pub fn text(
  status: Int,
  body: String,
) -> http_response.Response(mist.ResponseData) {
  http_response.new(status)
  |> http_response.prepend_header("content-type", text_content_type)
  |> http_response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}
