import app/message.{type Message}
import app/model.{type Model}
import lustre/element.{type Element}
import pages/home
import pages/not_found
import routes/route.{Home, NotFound}
import ui/layout/base_layout

pub fn view(model: Model) -> Element(Message) {
  let page = case model.route {
    Home -> home.view()
    NotFound -> not_found.view()
  }

  base_layout.view(page)
}
