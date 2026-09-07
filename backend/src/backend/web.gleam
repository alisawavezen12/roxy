import gleam/dynamic/decode
import gleam/http.{Get}
import gleam/json
import lustre/attribute
import lustre/element
import lustre/element/html
import pog
import shared
import shared/health.{Health}
import wisp.{type Request, type Response}

pub type Context {
  Context(db: pog.Connection, static_directory: String)
}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- middleware(req, ctx.static_directory)

  case req.method, wisp.path_segments(req) {
    Get, ["api", "health"] -> health_response(ctx)
    _, ["api", ..] ->
      json.object([#("error", json.string("not_found"))])
      |> json.to_string
      |> wisp.json_response(404)
    Get, [] -> serve_index()
    _, _ -> wisp.not_found()
  }
}

fn middleware(
  req: Request,
  static_directory: String,
  handle: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: static_directory)
  handle(req)
}

fn health_response(ctx: Context) -> Response {
  let db_status = case ping_db(ctx.db) {
    Ok(_) -> "ok"
    Error(_) -> "error"
  }
  Health(ok: db_status == "ok", db: db_status, service: shared.app_name)
  |> health.to_string
  |> wisp.json_response(200)
}

fn ping_db(db: pog.Connection) -> Result(Nil, Nil) {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  case
    pog.query("select 1")
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(Nil)
  }
}

fn serve_index() -> Response {
  html.html([attribute.lang("ru")], [
    html.head([], [
      html.meta([attribute.charset("utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1"),
      ]),
      html.title([], "Roxy"),
      html.script(
        [attribute.type_("module"), attribute.src("/static/frontend.js")],
        "",
      ),
    ]),
    html.body([], [html.div([attribute.id("app")], [])]),
  ])
  |> element.to_document_string
  |> wisp.html_response(200)
}
