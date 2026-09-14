import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(content: Element(Message)) -> Element(Message) {
  html.div([attribute.class("layout")], [content])
}
