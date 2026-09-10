import config/environment
import envoy
import gleam/int
import gleam/result

const default_ttl_seconds = 86_400

pub type SessionConfig {
  SessionConfig(
    ttl_seconds: Int,
    cookie_secure: Bool,
  )
}

pub fn load(environment: environment.Environment) -> Result(SessionConfig, String) {
  let ttl_seconds = case envoy.get("SESSION_TTL_SECONDS") {
    Ok(value) -> parse_ttl(value)
    Error(_) -> Ok(default_ttl_seconds)
  }
  use ttl_seconds <- result.try(ttl_seconds)
  Ok(SessionConfig(
    ttl_seconds: ttl_seconds,
    cookie_secure: environment == environment.Production,
  ))
}

fn parse_ttl(value: String) -> Result(Int, String) {
  case int.parse(value) {
    Ok(ttl) if ttl >= 60 && ttl <= 2_592_000 -> Ok(ttl)
    _ -> Error("SESSION_TTL_SECONDS must be between 60 and 2592000")
  }
}
