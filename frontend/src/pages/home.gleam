import app/message.{type Message}
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> Element(Message) {
  html.main([], [])
}
