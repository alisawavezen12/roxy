import app/message.{type Message}
import app/model.{type Model}
import lustre/element.{type Element}
import pages/not_found/not_found
import pages/onboarding/onboarding
import pages/user/user
import routes/route.{Home, NotFound, User}
import ui/layout/base_layout/base_layout

pub fn view(model: Model) -> Element(Message) {
  let page = case model.route {
    Home -> onboarding.view(model.auth)
    User(_id) -> user.view(model.user_tab, model.user_page, model.post_content)
    NotFound -> not_found.view()
  }

  base_layout.view(
    page,
    model.auth,
    model.auth_modal_open,
    model.settings_modal_open,
    model.sync_state,
    model.logout_state,
  )
}
