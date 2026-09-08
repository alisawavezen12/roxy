import gleam/http
import wisp

pub fn text(status: Int, body: String) -> wisp.Response {
  wisp.response(status)
  |> wisp.set_header("content-type", "text/plain; charset=utf-8")
  |> wisp.string_body(body)
}

pub fn method_not_allowed(methods: List(http.Method)) -> wisp.Response {
  wisp.method_not_allowed(methods)
  |> wisp.set_header("content-type", "text/plain; charset=utf-8")
}
