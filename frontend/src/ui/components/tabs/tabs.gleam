import gleam/list

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Tab(id) {
  Tab(id: id, label: String)
}

pub type Config(id, message) {
  Config(tabs: List(Tab(id)), active: id, on_select: fn(id) -> message)
}

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href("/ui/components/tabs/tabs.css"),
  ])
}

pub fn view(config: Config(id, message)) -> Element(message) {
  html.nav(
    [attribute.class("tabs"), attribute.attribute("role", "tablist")],
    list.map(config.tabs, fn(tab) {
      let active = tab.id == config.active
      html.button(
        [
          attribute.class(tab_class(active)),
          attribute.type_("button"),
          attribute.attribute("role", "tab"),
          attribute.attribute("aria-selected", bool_string(active)),
          event.on_click(config.on_select(tab.id)),
        ],
        [
          html.span([attribute.class("tabs__label")], [html.text(tab.label)]),
          html.span(
            [
              attribute.class("tabs__indicator"),
              attribute.attribute("aria-hidden", "true"),
            ],
            [],
          ),
        ],
      )
    }),
  )
}

fn tab_class(active: Bool) -> String {
  case active {
    True -> "tabs__tab tabs__tab--active"
    False -> "tabs__tab"
  }
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
