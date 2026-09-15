import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Size {
  Small
  Medium
  Large
  ExtraLarge
}

pub type Variant {
  Primary
  Secondary
  Danger
  Icon(icon: String)
}

pub type Config(message) {
  Config(label: String, size: Size, variant: Variant, on_click: message)
}

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href("/ui/components/button/button.css"),
  ])
}

pub fn view(config: Config(message)) -> Element(message) {
  html.button(
    [
      attribute.class(class_name(config.size, config.variant)),
      attribute.type_("button"),
      icon_label(config.variant, config.label),
      event.on_click(config.on_click),
    ],
    content(config),
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
    ExtraLarge -> "xl"
  }
}

fn icon_label(variant: Variant, label: String) -> attribute.Attribute(message) {
  case variant {
    Icon(_) -> attribute.attribute("aria-label", label)
    _ -> attribute.attribute("aria-hidden", "false")
  }
}

fn content(config: Config(message)) -> List(Element(message)) {
  case config.variant {
    Icon(icon) -> [
      html.span(
        [
          attribute.class("button__icon"),
          attribute.style("--button-icon", "url('/svg/" <> icon <> "')"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [],
      ),
    ]
    _ -> [html.text(config.label)]
  }
}

fn variant_name(variant: Variant) -> String {
  case variant {
    Primary -> "primary"
    Secondary -> "secondary"
    Danger -> "danger"
    Icon(_) -> "icon"
  }
}
