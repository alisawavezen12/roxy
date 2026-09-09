import gleam/bit_array
import gleam/string

pub const max_message_size = 65_536

pub fn text_within_limit(message: String) -> Bool {
  string.byte_size(message) <= max_message_size
}

pub fn binary_within_limit(message: BitArray) -> Bool {
  bit_array.byte_size(message) <= max_message_size
}
