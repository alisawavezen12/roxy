import app/message.{type Message}
import app/model.{type Model}
import app/update
import app/view
import lustre
import lustre/effect.{type Effect}
import routes/router

pub fn main() -> Nil {
  let app = lustre.application(init, update.update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags: Nil) -> #(Model, Effect(Message)) {
  update.init(router.current())
}
