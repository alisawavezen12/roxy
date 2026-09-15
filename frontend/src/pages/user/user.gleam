import app/message.{type Message}
import app/model.{type UserPageState, type UserTab}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/content_panel/content_panel
import pages/user/identity_panel/identity_panel
import pages/user/identity_panel/user_info/user_info

pub fn view(
  active_tab: UserTab,
  profile_state: UserPageState,
  post_content: String,
) -> Element(Message) {
  html.div([], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/user.css"),
    ]),
    content_panel.stylesheet(),
    identity_panel.stylesheet(),
    user_info.stylesheet(),
    html.main([attribute.class("user-page")], [
      html.section([attribute.class("user-page__content")], [
        content_panel.view(active_tab, post_content),
      ]),
      html.section([attribute.class("user-page__profile")], [
        user_info.view(profile_state),
      ]),
    ]),
  ])
}
