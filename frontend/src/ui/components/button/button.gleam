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

pub type IconAnimation {
  None
  Bounce
  Send
  Spin
}

pub type Variant {
  Primary
  Secondary
  Danger
  Icon(icon: String)
  IconAnimated(icon: String, animation: IconAnimation)
}

pub type Config(message) {
  Config(
    label: String,
    size: Size,
    variant: Variant,
    on_click: message,
    disabled: Bool,
  )
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
      disabled_attribute(config.disabled),
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

fn disabled_attribute(disabled: Bool) -> attribute.Attribute(message) {
  case disabled {
    True -> attribute.attribute("disabled", "true")
    False -> attribute.attribute("aria-disabled", "false")
  }
}

fn icon_label(variant: Variant, label: String) -> attribute.Attribute(message) {
  case variant {
    Icon(_) | IconAnimated(_, _) -> attribute.attribute("aria-label", label)
    _ -> attribute.attribute("aria-hidden", "false")
  }
}

fn content(config: Config(message)) -> List(Element(message)) {
  case config.variant {
    Icon(icon) | IconAnimated(icon, _) -> [
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
    IconAnimated(_, animation) -> "icon icon--" <> animation_name(animation)
  }
}

fn animation_name(animation: IconAnimation) -> String {
  case animation {
    None -> "none"
    Bounce -> "bounce"
    Send -> "send"
    Spin -> "spin"
  }
}
