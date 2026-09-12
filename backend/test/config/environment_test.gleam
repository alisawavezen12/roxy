import application/messages
import config/environment
import envoy
import gleeunit/should

pub fn missing_app_environment_is_rejected_test() {
  envoy.unset("APP_ENV")

  environment.load()
  |> should.equal(Error(messages.app_env_required))
}

pub fn empty_app_environment_is_rejected_test() {
  envoy.set("APP_ENV", "")

  environment.load()
  |> should.equal(Error(messages.app_env_required))
}
