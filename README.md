# JWT::Multisignature

## Usage

`JWT::Multisignature.generate_jwt(payload, private_keychain, algorithms)`

`JWT::Multisignature.generate_jws(payload, key_id, key_value, algorithm)`

`JWT::Multisignature.verify_jwt(jwt, public_keychain, options)`

`JWT::Multisignature.verify_jws(jws, payload, public_keychain, options)`

`JWT::Multisignature.add_jws(jwt, key_id, key_value, algorithm)`

`JWT::Multisignature.remove_jws(jwt, key_id)`

The full documentation is available at [rubydoc.info](http://www.rubydoc.info/gems/jwt-multisignature).
