import app/message.{type Message, NoOp, PostContentChanged}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import ui/components/button/button
import ui/components/textarea/textarea

pub fn stylesheet() -> Element(message) {
  html.div([], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href(
        "/pages/user/content_panel/wall/post_composer/post_composer.css",
      ),
    ]),
    textarea.stylesheet(),
  ])
}

pub fn view(post_content: String) -> Element(Message) {
  html.section([attribute.class("post-composer")], [
    textarea.view(
      textarea.Config(
        value: post_content,
        placeholder: "Write a post…",
        label: "Post content",
        on_input: PostContentChanged,
        on_keydown: fn(_) { NoOp },
      ),
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
