import gleam/erlang/process.{type Pid}

pub type Frame {
  Text(String)
  Binary(BitArray)
  Pong(BitArray)
  Ping(BitArray)
}

@external(erlang, "client_ffi", "connect")
pub fn connect(url: String, origin: String) -> Result(Pid, String)

@external(erlang, "client_ffi", "send_text")
pub fn send_text(connection: Pid, message: String) -> Result(Nil, String)

@external(erlang, "client_ffi", "send_binary")
pub fn send_binary(connection: Pid, message: BitArray) -> Result(Nil, String)

@external(erlang, "client_ffi", "send_ping")
pub fn send_ping(connection: Pid, payload: BitArray) -> Result(Nil, String)

@external(erlang, "client_ffi", "receive_frame")
pub fn receive_frame(connection: Pid, timeout_ms: Int) -> Result(Frame, String)

@external(erlang, "client_ffi", "close")
pub fn close(connection: Pid) -> Nil
