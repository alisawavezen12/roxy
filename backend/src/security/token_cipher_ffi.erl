-module(token_cipher_ffi).
-export([encrypt/2, decrypt/2]).

-define(VERSION, 1).
-define(IV_BYTES, 12).
-define(TAG_BYTES, 16).
-define(AAD, <<"roxy:dobrunia-auth-token:v1">>).

encrypt(Plaintext, Key) when is_binary(Plaintext), byte_size(Key) =:= 32 ->
    IV = crypto:strong_rand_bytes(?IV_BYTES),
    {Ciphertext, Tag} = crypto:crypto_one_time_aead(
        aes_256_gcm,
        Key,
        IV,
        Plaintext,
        ?AAD,
        ?TAG_BYTES,
        true
    ),
    <<?VERSION, IV/binary, Tag/binary, Ciphertext/binary>>.

decrypt(
    <<?VERSION, IV:?IV_BYTES/binary, Tag:?TAG_BYTES/binary, Ciphertext/binary>>,
    Key
) when byte_size(Key) =:= 32 ->
    try crypto:crypto_one_time_aead(
        aes_256_gcm,
        Key,
        IV,
        Ciphertext,
        ?AAD,
        Tag,
        false
    ) of
        error -> {error, invalid_ciphertext};
        Plaintext -> {ok, Plaintext}
    catch
        _:_ -> {error, invalid_ciphertext}
    end;
decrypt(_, _) ->
    {error, invalid_ciphertext}.
