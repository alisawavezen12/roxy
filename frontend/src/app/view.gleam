import app/message.{type Message}
import app/model.{type Model}
import lustre/element.{type Element}
import pages/not_found/not_found
import pages/onboarding/onboarding
import routes/route.{Home, NotFound}
import ui/layout/base_layout/base_layout

pub fn view(model: Model) -> Element(Message) {
  let page = case model.route {
    Home -> onboarding.view()
    NotFound -> not_found.view()
  }

  base_layout.view(page)
}
