import config/environment
import envoy
import gleeunit/should

pub fn missing_app_environment_is_rejected_test() {
  envoy.unset("APP_ENV")

  environment.load()
  |> should.equal(Error("APP_ENV environment variable is required"))
}

pub fn empty_app_environment_is_rejected_test() {
  envoy.set("APP_ENV", "")

  environment.load()
  |> should.equal(Error("APP_ENV environment variable is required"))
}
