import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Size {
  Small
  Medium
  Large
}

pub type Variant {
  Primary
  Secondary
  Danger
}

pub type Config(message) {
  Config(label: String, size: Size, variant: Variant, on_click: message)
}

pub fn view(config: Config(message)) -> Element(message) {
  html.button(
    [
      attribute.class(class_name(config.size, config.variant)),
      attribute.type_("button"),
      event.on_click(config.on_click),
    ],
    [html.text(config.label)],
  )
}

fn class_name(size: Size, variant: Variant) -> String {
  "button button--" <> size_name(size) <> " button--" <> variant_name(variant)
}

fn size_name(size: Size) -> String {
  case size {
    Small -> "sm"
    Medium -> "md"
    Large -> "lg"
  }
}

fn variant_name(variant: Variant) -> String {
  case variant {
    Primary -> "primary"
    Secondary -> "secondary"
    Danger -> "danger"
  }
}
