import app/message.{type Message, NoOp, OpenAuthModal}
import app/model.{type AuthState, Authenticated}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import ui/components/button/button

pub fn view(auth: AuthState) -> Element(Message) {
  html.main([attribute.class("onboarding")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/onboarding/onboarding.css"),
    ]),
    button.stylesheet(),
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
      html.div([attribute.class("onboarding__actions")], [action(auth)]),
    ]),
  ])
}

fn action(auth: AuthState) -> Element(Message) {
  case auth {
    Authenticated(user) ->
      html.a(
        [
          attribute.class("onboarding__action-link"),
          attribute.href("/user/" <> user.id),
        ],
        [
          button.view(button.Config(
            label: "Open my profile",
            size: button.Medium,
            variant: button.Primary,
            on_click: NoOp,
          )),
        ],
      )
    _ ->
      button.view(button.Config(
        label: "Get started",
        size: button.Medium,
        variant: button.Primary,
        on_click: OpenAuthModal,
      ))
  }
}
