import config/defaults
import config/environment
import envoy
import gleam/http
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{Uri}

pub type CorsConfig {
  CorsConfig(
    allowed_origins: List(String),
    allowed_methods: List(http.Method),
    allowed_headers: List(String),
  )
}

pub fn load(
  environment: environment.Environment,
) -> Result(CorsConfig, String) {
  use origins_value <- result.try(load_origins(environment))
  use allowed_origins <- result.try(parse_origins(origins_value))

  Ok(
    CorsConfig(
      allowed_origins:,
      allowed_methods: [http.Get, http.Head],
      allowed_headers: ["Content-Type"],
    ),
  )
}

fn load_origins(
  environment: environment.Environment,
) -> Result(String, String) {
  case envoy.get("CORS_ALLOWED_ORIGINS") {
    Ok(value) ->
      case string.trim(value) {
        "" -> missing_origins(environment)
        _ -> Ok(value)
      }
    Error(_) -> missing_origins(environment)
  }
}

fn missing_origins(
  environment: environment.Environment,
) -> Result(String, String) {
  case environment {
    environment.Development -> Ok(defaults.cors_allowed_origins)
    environment.Production ->
      Error(
        "CORS_ALLOWED_ORIGINS environment variable is required in production",
      )
  }
}

fn parse_origins(value: String) -> Result(List(String), String) {
  value
  |> string.split(",")
  |> list.try_map(parse_origin)
}

fn parse_origin(value: String) -> Result(String, String) {
  let origin = string.trim(value)
  let invalid = fn() {
    Error(
      "CORS_ALLOWED_ORIGINS must contain only HTTP origins in the form scheme://host[:port]; invalid value: "
      <> origin,
    )
  }

  case uri.parse(origin) {
    Ok(parsed) -> {
      case parsed {
        Uri(
          scheme: option.Some(scheme),
          userinfo: option.None,
          host: option.Some(host),
          port: port,
          path: "",
          query: option.None,
          fragment: option.None,
        )
          if host != "" && { scheme == "http" || scheme == "https" }
        ->
          case valid_port(port) && !string.ends_with(origin, ":") {
            True ->
              case uri.origin(parsed) {
                Ok(canonical_origin) -> Ok(string.lowercase(canonical_origin))
                Error(_) -> invalid()
              }
            False -> invalid()
          }
        _ -> invalid()
      }
    }
    Error(_) -> invalid()
  }
}

fn valid_port(port: option.Option(Int)) -> Bool {
  case port {
    option.None -> True
    option.Some(port) -> port > 0 && port < 65_536
  }
}
