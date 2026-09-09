@external(erlang, "ratelimit_clock_ffi", "monotonic_milliseconds")
fn monotonic_milliseconds() -> Int

pub fn now() -> Int {
  monotonic_milliseconds()
}
