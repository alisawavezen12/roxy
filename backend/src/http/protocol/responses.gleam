import wisp

pub fn text(status: Int, body: String) -> wisp.Response {
  wisp.response(status)
  |> wisp.set_header("content-type", "text/plain; charset=utf-8")
  |> wisp.string_body(body)
}
