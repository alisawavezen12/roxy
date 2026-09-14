import app/message.{type Message, NoOp}
import app/model.{type Model, Model}
import lustre/effect.{type Effect}
import routes/route.{type Route}

pub fn init(route: Route) -> #(Model, Effect(Message)) {
  #(Model(route:), effect.none())
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    NoOp -> #(model, effect.none())
  }
}
