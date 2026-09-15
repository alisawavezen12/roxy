import lustre/effect.{type Effect}

pub fn load_current_user() -> Effect(String) {
  effect.from(load_current_user_ffi)
}

pub fn start_sso_login() -> Effect(message) {
  effect.from(fn(_) { start_sso_login_ffi() })
}

@external(javascript, "./auth_ffi.mjs", "loadCurrentUser")
fn load_current_user_ffi(dispatch: fn(String) -> Nil) -> Nil

@external(javascript, "./auth_ffi.mjs", "startSsoLogin")
fn start_sso_login_ffi() -> Nil
