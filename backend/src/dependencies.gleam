import config/app
import pog

pub type Dependencies {
  Dependencies(config: app.AppConfig, postgres: pog.Connection)
}

pub fn new(config: app.AppConfig, postgres: pog.Connection) -> Dependencies {
  Dependencies(config:, postgres:)
}
