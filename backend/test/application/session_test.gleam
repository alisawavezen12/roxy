import application/services/session
import gleam/bit_array
import gleam/crypto
import gleeunit/should

pub fn token_hash_is_one_way_and_deterministic_test() {
  let token = "test-session-token"
  let hash = session.token_hash(token)

  hash
  |> should.equal(crypto.hash(crypto.Sha256, <<token:utf8>>))
  bit_array.byte_size(hash)
  |> should.equal(32)
  hash
  |> should.not_equal(<<token:utf8>>)
}

pub fn random_session_tokens_are_not_reused_test() {
  let first =
    crypto.strong_random_bytes(32) |> bit_array.base64_url_encode(False)
  let second =
    crypto.strong_random_bytes(32) |> bit_array.base64_url_encode(False)

  first
  |> should.not_equal(second)
}
