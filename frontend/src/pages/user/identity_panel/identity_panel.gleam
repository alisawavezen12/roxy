import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(user_id: String) -> Element(Message) {
  html.aside([attribute.class("identity-panel")], [
    html.section([attribute.class("identity-panel__identity")], [
      html.div([attribute.class("identity-panel__avatar")], [html.text("M")]),
      html.div([attribute.class("identity-panel__name-row")], [
        html.h2([], [html.text("Maya Chen")]),
        html.span(
          [
            attribute.class("identity-panel__status"),
            attribute.title("building weird things"),
          ],
          [html.text("✦")],
        ),
      ]),
      html.p([attribute.class("identity-panel__handle")], [
        html.text("@" <> user_id),
      ]),
    ]),
    html.section([attribute.class("identity-panel__meta")], [
      html.p([], [html.text("Joined Sep 2026")]),
      html.div([attribute.class("identity-panel__stats")], [
        html.span([], [html.text("24 posts")]),
        html.span([attribute.class("identity-panel__stars")], [
          html.span(
            [
              attribute.class("identity-panel__star-icon"),
              attribute.attribute("aria-hidden", "true"),
            ],
            [],
          ),
          html.text("42"),
        ]),
      ]),
    ]),
    html.p([attribute.class("identity-panel__bio")], [
      html.text(
        "Designer, maker, and curious human exploring better ways to work together.",
      ),
    ]),

    html.nav([attribute.class("identity-panel__links")], [
      html.a([attribute.href("#website")], [html.text("Website")]),
      html.a([attribute.href("#github")], [html.text("GitHub")]),
      html.a([attribute.href("#contact")], [html.text("Contact")]),
    ]),
  ])
}
