import gleam/bit_array
import gleam/crypto
import gleeunit/should
import security/token_cipher

pub fn encrypted_token_round_trips_test() {
  let key = token_cipher.derive_key("a sufficiently long encryption secret")
  let ciphertext = token_cipher.encrypt("refresh-token-secret", key)

  ciphertext
  |> token_cipher.decrypt(key)
  |> should.equal(Ok("refresh-token-secret"))
  ciphertext
  |> should.not_equal(<<"refresh-token-secret":utf8>>)
}

pub fn encryption_uses_a_fresh_nonce_test() {
  let key = token_cipher.derive_key("a sufficiently long encryption secret")

  token_cipher.encrypt("same-token", key)
  |> should.not_equal(token_cipher.encrypt("same-token", key))
}

pub fn tampered_ciphertext_is_rejected_test() {
  let key = token_cipher.derive_key("a sufficiently long encryption secret")
  let ciphertext = token_cipher.encrypt("refresh-token-secret", key)
  let tampered = case ciphertext {
    <<first, rest:bytes>> -> {
      let changed = first + 1
      <<changed, rest:bits>>
    }
    _ -> panic as "Expected ciphertext"
  }

  tampered
  |> token_cipher.decrypt(key)
  |> should.equal(Error(token_cipher.InvalidCiphertext))
}

pub fn key_derivation_produces_aes_256_key_test() {
  token_cipher.derive_key("secret")
  |> bit_array.byte_size
  |> should.equal(32)
  token_cipher.derive_key("secret")
  |> should.equal(crypto.hash(crypto.Sha256, <<"secret":utf8>>))
}
