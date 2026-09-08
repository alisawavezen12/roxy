import envoy
import gleam/list

import gleam/string
import simplifile

pub fn load() -> Result(Nil, String) {
  case simplifile.read("../.env") {
    Ok(contents) -> {
      contents
      |> string.split("\n")
      |> list.each(set_variable)
      Ok(Nil)
    }
    Error(_) -> Ok(Nil)
  }
}

fn set_variable(line: String) -> Nil {
  let line = string.trim(line)

  case line {
    "" | "#" <> _ -> Nil
    _ -> {
      case string.split_once(line, "=") {
        Ok(#(name, value)) -> envoy.set(string.trim(name), string.trim(value))
        Error(_) -> Nil
      }
    }
  }
}
