pub const secret_key_base_too_short = "SECRET_KEY_BASE must be at least 64 characters long"

pub const port_invalid = "PORT must be an integer between 1 and 65535"

pub const app_env_required = "APP_ENV environment variable is required"

pub const session_ttl_invalid = "SESSION_TTL_SECONDS must be between 60 and 2592000"

pub const cors_origins_required = "CORS_ALLOWED_ORIGINS environment variable is required in production"

pub const cors_origins_invalid_prefix = "CORS_ALLOWED_ORIGINS must contain only HTTP origins in the form scheme://host[:port]; invalid value: "

pub const public_base_url_https_required = "PUBLIC_BASE_URL must use https:// outside development"

pub const public_base_url_scheme_invalid = "PUBLIC_BASE_URL must use http:// or https://"

pub const public_base_url_invalid = "PUBLIC_BASE_URL must be an absolute http(s) URL"

pub const trusted_proxy_ips_empty = "TRUSTED_PROXY_IPS must not contain empty entries"

pub const database_lock_timeout_exceeded = "DATABASE_LOCK_TIMEOUT_MS must not exceed DATABASE_STATEMENT_TIMEOUT_MS"

pub const database_statement_timeout_exceeded = "DATABASE_STATEMENT_TIMEOUT_MS must not exceed DATABASE_TRANSACTION_TIMEOUT_MS"

pub const database_idle_timeout_exceeded = "DATABASE_IDLE_IN_TRANSACTION_TIMEOUT_MS must not exceed DATABASE_TRANSACTION_TIMEOUT_MS"

pub const invalid_database_url = "Invalid DATABASE_URL"

pub const postgres_connection_failed = "PostgreSQL connection failed"

pub fn invalid_app_environment(value: String) -> String {
  "APP_ENV must be either development or production, got: " <> value
}

pub fn required_in_production(name: String) -> String {
  name <> " environment variable is required in production"
}

pub fn positive_integer_required(name: String) -> String {
  name <> " must be a positive integer"
}

pub fn invalid_cors_origin(origin: String) -> String {
  cors_origins_invalid_prefix <> origin
}
