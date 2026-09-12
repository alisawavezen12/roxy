import config
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp
import health.{type Health}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type Surface {
  Wall
  Board
}

type Model {
  Model(surface: Surface, health: Option(Result(Health, Nil)))
}

type Message {
  UserOpenedWall
  UserOpenedBoard
  ApiReturnedHealth(Result(Health, rsvp.Error(String)))
}

fn init(_flags: Nil) -> #(Model, Effect(Message)) {
  #(Model(surface: Wall, health: None), fetch_health())
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    UserOpenedWall -> #(Model(..model, surface: Wall), effect.none())
    UserOpenedBoard -> #(Model(..model, surface: Board), effect.none())
    ApiReturnedHealth(Ok(health)) -> #(
      Model(..model, health: Some(Ok(health))),
      effect.none(),
    )
    ApiReturnedHealth(Error(_)) -> #(
      Model(..model, health: Some(Error(Nil))),
      effect.none(),
    )
  }
}

fn fetch_health() -> Effect(Message) {
  rsvp.get(
    config.api_origin <> "/health",
    rsvp.expect_json(health.decoder(), ApiReturnedHealth),
  )
}

fn view(model: Model) -> Element(Message) {
  html.div([attribute.class("shell")], [
    html.style([], css),
    html.header([attribute.class("top")], [
      html.p([attribute.class("mark")], [html.text("Roxy")]),
      html.div([attribute.class("switch"), attribute.role("group")], [
        surface_button("Стена", model.surface == Wall, UserOpenedWall),
        surface_button("Доска", model.surface == Board, UserOpenedBoard),
      ]),
    ]),
    html.main([attribute.class("stage")], [view_surface(model.surface)]),
    html.footer([attribute.class("status")], [view_health(model.health)]),
  ])
}

fn surface_button(
  label: String,
  active: Bool,
  message: Message,
) -> Element(Message) {
  html.button(
    [
      attribute.type_("button"),
      attribute.aria_pressed(case active {
        True -> "true"
        False -> "false"
      }),
      attribute.class(case active {
        True -> "on"
        False -> ""
      }),
      event.on_click(message),
    ],
    [html.text(label)],
  )
}

fn view_surface(surface: Surface) -> Element(Message) {
  case surface {
    Wall ->
      html.p([attribute.class("empty")], [
        html.text("Стена пустая. Посты появятся здесь."),
      ])
    Board ->
      html.p([attribute.class("empty")], [
        html.text("Доска пустая. Объекты появятся здесь."),
      ])
  }
}

fn view_health(health: Option(Result(Health, Nil))) -> Element(Message) {
  let text = case health {
    None -> "проверяю backend…"
    Some(Ok(status)) if status.db == "ok" -> "postgres ок"
    Some(Ok(_)) -> "backend жив, postgres недоступен"
    Some(Error(_)) -> "API недоступен или не готов (возможна ошибка БД)"
  }

  html.p([], [html.text(text)])
}

const css = "
  :root {
    color-scheme: light;
    --ink: #1c1712;
    --muted: #6f675e;
    --paper: #f3eee6;
    --card: #fffaf3;
    --line: #ddd4c6;
    --accent: #b9582a;
  }
  * { box-sizing: border-box; }
  html, body, #app { margin: 0; min-height: 100%; }
  body {
    font: 16px/1.5 Georgia, 'Iowan Old Style', 'Palatino Linotype', serif;
    background: var(--paper);
    color: var(--ink);
  }
  .shell {
    max-width: 44rem;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    gap: 2rem;
  }
  .top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
  }
  .mark {
    margin: 0;
    font-size: 1.5rem;
    letter-spacing: 0.04em;
  }
  .switch {
    display: flex;
    padding: 0.2rem;
    border: 1px solid var(--line);
    border-radius: 999px;
    background: var(--card);
  }
  .switch button {
    appearance: none;
    border: 0;
    background: transparent;
    color: var(--muted);
    font: inherit;
    padding: 0.35rem 0.9rem;
    border-radius: 999px;
    cursor: pointer;
  }
  .switch button.on {
    background: var(--ink);
    color: var(--card);
  }
  .stage {
    flex: 1;
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 1.25rem;
    min-height: 22rem;
    display: grid;
    place-items: center;
    padding: 2rem;
  }
  .empty {
    margin: 0;
    color: var(--muted);
    text-align: center;
  }
  .status {
    color: var(--muted);
    font-size: 0.9rem;
  }
  .status p { margin: 0; }
"
