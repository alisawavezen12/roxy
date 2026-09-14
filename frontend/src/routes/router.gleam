import routes/route.{type Route}

pub fn current() -> Route {
  route.from_path(pathname())
}

@external(javascript, "./router_ffi.mjs", "pathname")
fn pathname() -> String
