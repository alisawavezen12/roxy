import app/message.{type Message, NoOp}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import ui/components/button/button

pub fn view() -> Element(Message) {
  html.main([attribute.class("onboarding")], [
    html.div([attribute.class("onboarding__content")], [
      html.p([attribute.class("onboarding__eyebrow")], [
        html.text("Welcome to Roxy"),
      ]),
      html.h1([], [html.text("A calmer way to work together.")]),
      html.p([attribute.class("onboarding__description")], [
        html.text(
          "Roxy brings your conversations, ideas, and shared work into one simple space.",
        ),
      ]),
      html.div([attribute.class("onboarding__actions")], [
        button.view(button.Config(
          label: "Get started",
          size: button.Large,
          variant: button.Primary,
          on_click: NoOp,
        )),
        button.view(button.Config(
          label: "Learn more",
          size: button.Medium,
          variant: button.Secondary,
          on_click: NoOp,
        )),
      ]),
    ]),
  ])
}
