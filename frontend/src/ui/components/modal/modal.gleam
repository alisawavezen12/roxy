import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Config(message) {
  Config(
    title: String,
    close_label: String,
    on_close: message,
    children: List(Element(message)),
  )
}

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href("/ui/components/modal/modal.css"),
  ])
}

pub fn view(config: Config(message)) -> Element(message) {
  html.div(
    [attribute.class("modal"), attribute.attribute("role", "presentation")],
    [
      html.button(
        [
          attribute.class("modal__backdrop"),
          attribute.type_("button"),
          attribute.attribute("aria-label", config.close_label),
          event.on_click(config.on_close),
        ],
        [],
      ),
      html.section(
        [
          attribute.class("modal__dialog"),
          attribute.attribute("role", "dialog"),
          attribute.attribute("aria-modal", "true"),
          attribute.attribute("aria-labelledby", "modal-title"),
        ],
        [
          html.div([attribute.class("modal__header")], [
            html.h2([attribute.id("modal-title")], [html.text(config.title)]),
            html.button(
              [
                attribute.class("modal__close"),
                attribute.type_("button"),
                attribute.attribute("aria-label", config.close_label),
                event.on_click(config.on_close),
              ],
              [html.span([attribute.attribute("aria-hidden", "true")], [])],
            ),
          ]),
          html.div([attribute.class("modal__body")], config.children),
        ],
      ),
    ],
  )
}
