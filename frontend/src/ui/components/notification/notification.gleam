import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Kind {
  Success
  Error
}

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href("/ui/components/notification/notification.css"),
  ])
}

pub fn view(kind: Kind, message: String, tooltip: String) -> Element(message) {
  let kind_name = case kind {
    Success -> "success"
    Error -> "error"
  }
  html.div(
    [
      attribute.class("notification notification--" <> kind_name),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-live", "polite"),
      attribute.title(tooltip),
    ],
    [html.text(message)],
  )
}

pub fn dismiss_after() -> Effect(Nil) {
  effect.from(fn(dispatch) { dismiss_after_ffi(fn() { dispatch(Nil) }) })
}

@external(javascript, "./notification_ffi.mjs", "dismissAfter")
fn dismiss_after_ffi(callback: fn() -> Nil) -> Nil
