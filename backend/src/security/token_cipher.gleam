import gleam/crypto

pub type CipherError {
  InvalidCiphertext
}

pub fn derive_key(secret: String) -> BitArray {
  crypto.hash(crypto.Sha256, <<secret:utf8>>)
}

@external(erlang, "token_cipher_ffi", "encrypt")
pub fn encrypt(plaintext: String, key: BitArray) -> BitArray

@external(erlang, "token_cipher_ffi", "decrypt")
pub fn decrypt(
  ciphertext: BitArray,
  key: BitArray,
) -> Result(String, CipherError)
