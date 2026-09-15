import app/message.{type Message}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/content_panel/wall/post_composer/post_composer

pub fn stylesheet() -> Element(message) {
  html.div([attribute.class("user-wall__styles")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/content_panel/wall/wall.css"),
    ]),
    post_composer.stylesheet(),
  ])
}

pub fn view(post_content: String) -> Element(Message) {
  html.div([attribute.class("user-wall")], [
    post_composer.view(post_content),
    html.div([attribute.class("user-wall__empty")], [
      html.span(
        [
          attribute.class("user-wall__icon"),
          attribute.attribute("aria-hidden", "true"),
          attribute.style("--empty-icon", "url('/svg/mail.svg')"),
        ],
        [],
      ),
      html.p([], [html.text("This user has no posts.")]),
    ]),
  ])
}
