import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> Element(Message) {
  html.main([attribute.class("not-found")], [
    html.h1([], [html.text("404")]),
    html.p([], [html.text("Page not found")]),
  ])
}
