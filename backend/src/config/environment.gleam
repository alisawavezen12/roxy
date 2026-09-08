import envoy

pub type Environment {
  Development
  Production
}

pub fn load() -> Result(Environment, String) {
  case envoy.get("APP_ENV") {
    Error(_) | Ok("") -> Ok(Development)
    Ok("development") -> Ok(Development)
    Ok("production") -> Ok(Production)
    Ok(value) ->
      Error("APP_ENV must be either development or production, got: " <> value)
  }
}
