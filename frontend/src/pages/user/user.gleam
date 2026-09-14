import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> Element(Message) {
  html.main([attribute.class("user-page")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/user.css"),
    ]),
    html.section([attribute.class("user-wall")], [
      html.div([attribute.class("user-page__heading")], [
        html.p([attribute.class("user-page__eyebrow")], [html.text("Profile")]),
        html.h1([], [html.text("Maya's wall")]),
      ]),
      post(
        "A small idea can become a shared place.",
        "Just now",
        "I am collecting notes, questions, and things worth building together.",
      ),
      post(
        "What are you working on?",
        "Yesterday",
        "Leave a thought, share a link, or start a conversation.",
      ),
    ]),
    html.aside([attribute.class("user-card")], [
      html.div([attribute.class("user-avatar")], [html.text("M")]),
      html.h2([], [html.text("Maya Chen")]),
      html.p([attribute.class("user-handle")], [html.text("@mayachen")]),
      html.p([attribute.class("user-status")], [html.text("Building quietly ✦")]),
      html.p([attribute.class("user-bio")], [
        html.text(
          "Designer, maker, and curious human exploring better ways to work together.",
        ),
      ]),
      html.nav([attribute.class("user-links")], [
        html.a([attribute.href("#website")], [html.text("Website")]),
        html.a([attribute.href("#github")], [html.text("GitHub")]),
        html.a([attribute.href("#contact")], [html.text("Contact")]),
      ]),
    ]),
  ])
}

fn post(title: String, time: String, body: String) -> Element(Message) {
  html.article([attribute.class("post")], [
    html.div([attribute.class("post__meta")], [
      html.span([], [html.text(time)]),
    ]),
    html.h2([], [html.text(title)]),
    html.p([], [html.text(body)]),
  ])
}
