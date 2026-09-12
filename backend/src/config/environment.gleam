import application/messages
import envoy

pub type Environment {
  Development
  Production
}

pub fn load() -> Result(Environment, String) {
  case envoy.get("APP_ENV") {
    Error(_) | Ok("") -> Error(messages.app_env_required)
    Ok("development") -> Ok(Development)
    Ok("production") -> Ok(Production)
    Ok(value) -> Error(messages.invalid_app_environment(value))
  }
}
