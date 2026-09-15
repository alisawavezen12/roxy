import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(content: Element(Message)) -> Element(Message) {
  html.div([attribute.class("layout")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/ui/layout/base_layout/base_layout.css"),
    ]),
    html.div([attribute.class("layout__content")], [content]),
  ])
}
