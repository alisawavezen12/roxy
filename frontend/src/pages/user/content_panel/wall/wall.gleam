import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href("/pages/user/wall/wall.css"),
  ])
}

pub fn view() -> Element(Message) {
  html.div([attribute.class("user-wall")], [
    html.span(
      [
        attribute.class("user-wall__icon"),
        attribute.attribute("aria-hidden", "true"),
        attribute.style("--empty-icon", "url('/svg/mail.svg')"),
      ],
      [],
    ),
    html.p([], [html.text("This user has no posts.")]),
  ])
}
