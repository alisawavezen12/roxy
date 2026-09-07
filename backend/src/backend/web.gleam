
import gleam/dynamic/decode



import lustre/attribute
import lustre/element
import lustre/element/html
import pog
import shared
import shared/health.{type Health, Health}
import wisp.{type Response}

pub type Context {
  Context(db: pog.Connection, static_directory: String)
}


pub fn health_response(ctx: Context) -> Response {
  let db_status = case ping_db(ctx.db) {
    Ok(_) -> "ok"
    Error(_) -> "error"
  }
  Health(ok: db_status == "ok", db: db_status, service: shared.app_name)
  |> readiness_response
}

pub fn readiness_response(status: Health) -> Response {
  let code = case status.ok {
    True -> 200
    False -> 503
  }
  status
  |> health.to_string
  |> wisp.json_response(code)
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

pub fn serve_index() -> Response {
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
