import app/message.{type Message, NoOp, PostContentChanged}
import gleam/string
import lustre/attribute
import lustre/element.{type Element, element}
import lustre/element/html
import lustre/event
import ui/components/button/button

pub fn stylesheet() -> Element(message) {
  html.link([
    attribute.rel("stylesheet"),
    attribute.href(
      "/pages/user/content_panel/wall/post_composer/post_composer.css",
    ),
  ])
}

pub fn view(post_content: String) -> Element(Message) {
  html.section([attribute.class("post-composer")], [
    element(
      "textarea",
      [
        attribute.class("post-composer__input"),
        attribute.attribute("placeholder", "Write a post…"),
        attribute.attribute("aria-label", "Post content"),
        attribute.attribute("rows", "1"),
        event.on_input(PostContentChanged),
      ],
      [],
    ),
    html.div([attribute.class("post-composer__actions")], [
      button.view(button.Config(
        label: "Choose emoji",
        size: button.Medium,
        variant: button.IconAnimated("emoji.svg", button.Bounce),
        on_click: NoOp,
        disabled: False,
      )),
      button.view(button.Config(
        label: "Attach file",
        size: button.Medium,
        variant: button.IconAnimated("upload.svg", button.Bounce),
        on_click: NoOp,
        disabled: False,
      )),
      button.view(button.Config(
        label: "Send post",
        size: button.Medium,
        variant: button.IconAnimated("send.svg", button.Send),
        on_click: NoOp,
        disabled: string.trim(post_content) == "",
      )),
    ]),
  ])
}
