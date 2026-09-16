import gleam/json
import lustre/attribute
import lustre/element.{type Element, element}
import lustre/event

pub type Config(message) {
  Config(
    value: String,
    placeholder: String,
    label: String,
    on_input: fn(String) -> message,
    on_keydown: fn(String) -> message,
  )
}

pub fn stylesheet() -> Element(message) {
  element(
    "link",
    [
      attribute.rel("stylesheet"),
      attribute.href("/ui/components/textarea/textarea.css"),
    ],
    [],
  )
}

pub fn view(config: Config(message)) -> Element(message) {
  element(
    "textarea",
    [
      attribute.class("textarea"),
      attribute.attribute("aria-label", config.label),
      attribute.attribute("placeholder", config.placeholder),
      attribute.property("value", json.string(config.value)),
      event.on_input(config.on_input),
      event.on_keydown(config.on_keydown),
    ],
    [],
  )
}
