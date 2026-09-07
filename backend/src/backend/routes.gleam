import backend/web
import gleam/json
import gleam/http
import wisp

pub fn dispatch(req: wisp.Request, context: web.Context) -> wisp.Response {
  case req.method, wisp.path_segments(req) {
    http.Get, ["api", "health"] -> web.health_response(context)
    _, ["api", ..] ->
      json.object([#("error", json.string("not_found"))])
      |> json.to_string
      |> wisp.json_response(404)
    http.Get, [] -> web.serve_index()
    _, _ -> wisp.not_found()
  }
}
