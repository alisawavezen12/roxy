import app/message.{type Message}
import app/model.{
  type UserPageState, UserLoadFailed, UserLoaded, UserLoading, UserNotFound,
}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/identity_panel/identity_panel

pub fn view(profile_state: UserPageState) -> Element(Message) {
  html.main([attribute.class("user-page")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/user.css"),
    ]),
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/identity_panel/identity_panel.css"),
    ]),
    html.section([attribute.class("user-page__posts")], posts()),
    html.section(
      [attribute.class("user-page__profile")],
      profile(profile_state),
    ),
  ])
}

fn posts() -> List(Element(Message)) {
  [empty_state("mail.svg", "This user has no posts yet.")]
}

fn profile(state: UserPageState) -> List(Element(Message)) {
  case state {
    UserLoading -> [status("Loading user…")]
    UserLoaded(profile) -> [identity_panel.view(profile)]
    UserNotFound -> [empty_profile_state()]
    UserLoadFailed -> [status("Unable to load this user.")]
  }
}

fn empty_state(icon: String, message: String) -> Element(Message) {
  html.div([attribute.class("user-page__empty")], [
    html.span(
      [
        attribute.class("user-page__empty-icon"),
        attribute.attribute("aria-hidden", "true"),
        attribute.style("--empty-icon", "url('/svg/" <> icon <> "')"),
      ],
      [],
    ),
    html.p([], [html.text(message)]),
  ])
}

fn empty_profile_state() -> Element(Message) {
  html.div([attribute.class("user-page__profile-empty")], [
    empty_state("user.svg", "This user does not exist."),
  ])
}

fn status(message: String) -> Element(Message) {
  html.p([attribute.class("user-page__status")], [html.text(message)])
}
