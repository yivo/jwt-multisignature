# encoding: UTF-8
# frozen_string_literal: true

require "jwt"
require "openssl"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/slice"
require "active_support/core_ext/hash/indifferent_access"

module JWT
  #
  # The module provides tools for encoding/decoding JWT with multiple signatures.
  #
  module Multisignature
    class << self
      #
      # Generates new JWT based on payload, keys, and algorithms.
      #
      # @param payload [Hash]
      # @param private_keychain [Hash]
      #   The hash which consists of pairs: key ID => private key.
      #   The key may be presented as string in PEM format or as instance of {OpenSSL::PKey::PKey}.
      # @param algorithms
      #   The hash which consists of pairs: key ID => signature algorithm.
      # @return [Hash]
      #   The JWT in the format as defined in RFC 7515.
      #   Example:
      #     { payload: "eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ",
      #       signatures: [
      #         { protected: "eyJhbGciOiJSUzI1NiJ9",
      #           header: { kid: "2010-12-29" },
      #           signature: "cC4hiUPoj9Eetdgtv3hF80EGrhuB__dzERat0XF9g2VtQgr9PJbu3XOiZj5RZmh7AAuHIm4Bh-0Qc_lF5YKt_O8W2Fp5jujGbds9uJdbF9CUAr7t1dnZcAcQjbKBYNX4BAynRFdiuB--f_nZLgrnbyTyWzO75vRK5h6xBArLIARNPvkSjtQBMHlb1L07Qe7K0GarZRmB_eSN9383LcOLn6_dO--xi12jzDwusC-eOkHWEsqtFZESc6BfI7noOPqvhJ1phCnvWh6IeYI2w9QOYEUipUTI8np6LbgGY9Fs98rqVt5AXLIhWkWywlVmtVrBp0igcN_IoypGlUPQGe77Rw"
      #         },
      #         { protected: "eyJhbGciOiJFUzI1NiJ9",
      #           header: { kid: "e9bc097a-ce51-4036-9562-d2ade882db0d" },
      #           signature: "DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8ISlSApmWQxfKTUJqPP3-Kg6NU1Q"
      #         }
      #       ]
      #     }
      # @raise [JWT::EncodeError]
      def generate_jwt(payload, private_keychain, algorithms)
        algorithms_mapping = algorithms.with_indifferent_access
        { payload:    base64_encode(::JWT::JSON.generate(payload)),
          signatures: private_keychain.map do |id, value|
            generate_jws(payload, id, value, algorithms_mapping.fetch(id))
          end }
      end

      #
      # Generates and adds new JWS to existing JWT.
      #
      # @param jwt [Hash]
      #   The existing JWT.
      # @param key_id [String]
      #   The JWS key ID.
      # @param key_value [String, OpenSSL::PKey::PKey]
      #   The private key in PEM format or as instance of {OpenSSL::PKey::PKey}.
      # @param algorithm [String]
      #   The signature algorithm.
      # @return [Hash]
      #   The JWT with added JWS.
      # @raise [JWT::EncodeError]
      def add_jws(jwt, key_id, key_value, algorithm)
        remove_jws(jwt, key_id).tap do |new_jwt|
          payload = ::JWT::JSON.parse(base64_decode(new_jwt.fetch(:payload)))
          new_jwt.fetch(:signatures) << generate_jws(payload, key_id, key_value, algorithm)
        end
      end

      #
      # Removes all JWS associated with given key ID.
      #
      # @param jwt [Hash]
      #   The existing JWT.
      # @param key_id [String]
      #   The key ID to match JWS by.
      # @return [Hash]
      #   The JWT with all matched JWS removed.
      def remove_jws(jwt, key_id)
        jwt.deep_symbolize_keys.tap do |new_jwt|
          new_jwt[:signatures] = new_jwt.fetch(:signatures, []).reject do |jws|
            jws.fetch(:header).fetch(:kid) == key_id
          end
        end
      end

      #
      # Verifies JWT.
      #
      # @param jwt [Hash]
      #   The JWT in the format as defined in RFC 7515.
      #   Example:
      #     { "payload" => "eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ",
      #       "signatures" => [
      #         { "protected" => "eyJhbGciOiJSUzI1NiJ9",
      #           "header" => { "kid" => "2010-12-29" },
      #           "signature" => "cC4hiUPoj9Eetdgtv3hF80EGrhuB__dzERat0XF9g2VtQgr9PJbu3XOiZj5RZmh7AAuHIm4Bh-0Qc_lF5YKt_O8W2Fp5jujGbds9uJdbF9CUAr7t1dnZcAcQjbKBYNX4BAynRFdiuB--f_nZLgrnbyTyWzO75vRK5h6xBArLIARNPvkSjtQBMHlb1L07Qe7K0GarZRmB_eSN9383LcOLn6_dO--xi12jzDwusC-eOkHWEsqtFZESc6BfI7noOPqvhJ1phCnvWh6IeYI2w9QOYEUipUTI8np6LbgGY9Fs98rqVt5AXLIhWkWywlVmtVrBp0igcN_IoypGlUPQGe77Rw"
      #         },
      #         { "protected" => "eyJhbGciOiJFUzI1NiJ9",
      #           "header" => { "kid" => "e9bc097a-ce51-4036-9562-d2ade882db0d" },
      #           "signature" => "DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8ISlSApmWQxfKTUJqPP3-Kg6NU1Q"
      #         }
      #       ]
      #     }
      # @param public_keychain [Hash]
      #   The hash which consists of pairs: key ID => public key.
      #   The key may be presented as string in PEM format or as instance of {OpenSSL::PKey::PKey}.
      #   The implementation only verifies signatures for which public key exists in keychain.
      # @param options [Hash]
      #   The rules for verifying JWT. The variable «algorithms» is always overwritten by the value from JWS header.
      # @return [Hash]
      #   The returning value contains payload, list of verified, and unverified signatures (key ID).
      #   Example:
      #     { payload:    { sub: "session", profile: { email: "username@mailbox.example" },
      #       verified:   [:"backend-1.mycompany.example", :"backend-3.mycompany.example"],
      #       unverified: [:"backend-2.mycompany.example"] }
      #     }
      # @raise [JWT::DecodeError]
      def verify_jwt(jwt, public_keychain, options = {})
        keychain           = public_keychain.with_indifferent_access
        serialized_payload = base64_decode(jwt.fetch("payload"))
        payload            = ::JWT::JSON.parse(serialized_payload)
        verified           = []
        unverified         = []

        jwt.fetch("signatures").each do |jws|
          key_id = jws.fetch("header").fetch("kid")
          if keychain.key?(key_id)
            verify_jws(jws, payload, public_keychain, options)
            verified << key_id
          else
            unverified << key_id
          end
        end
        { payload:    payload.deep_symbolize_keys,
          verified:   verified.uniq.map(&:to_sym),
          unverified: unverified.uniq.map(&:to_sym) }
      end

      #
      # Generates new JWS based on payload, key, and algorithm.
      #
      # @param payload [Hash]
      # @param key_id [String]
      #   The value which is used as «kid» in JWS header.
      # @param key_value [String, OpenSSL::PKey::PKey]
      #   The private key.
      # @param algorithm [String]
      #   The signature algorithm.
      # @return [Hash]
      #   The JWS in the format as defined in RFC 7515.
      #   Example:
      #     { protected: "eyJhbGciOiJFUzI1NiJ9",
      #       header: {
      #         kid: "e9bc097a-ce51-4036-9562-d2ade882db0d"
      #       },
      #       signature: "DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8ISlSApmWQxfKTUJqPP3-Kg6NU1Q"
      #     }
      # @raise [JWT::EncodeError]
      def generate_jws(payload, key_id, key_value, algorithm)
        protected, _, signature = JWT.encode(payload, to_pem_or_key(key_value, algorithm), algorithm).split(".")
        { protected: protected,
          header:    { kid: key_id },
          signature: signature }
      end

      #
      # Verifies JWS.
      #
      # @param jws [Hash]
      #   The JWS in the format as defined in RFC 7515.
      #   Example:
      #     { "protected" => "eyJhbGciOiJFUzI1NiJ9",
      #       "header" => {
      #         "kid" => "e9bc097a-ce51-4036-9562-d2ade882db0d"
      #       },
      #       "signature" => "DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8ISlSApmWQxfKTUJqPP3-Kg6NU1Q"
      #     }
      # @param payload [Hash]
      # @param public_keychain [Hash]
      #   The hash which consists of pairs: key ID => public key.
      #   The key may be presented as string in PEM format or as instance of {OpenSSL::PKey::PKey}.
      # @param options [Hash]
      #   The rules for verifying JWT. The variable «algorithms» is always overwritten by the value from JWS header.
      # @return [Hash]
      #   Returns payload if signature is valid.
      # @raise [JWT::DecodeError]
      def verify_jws(jws, payload, public_keychain, options = {})
        encoded_header     = jws.fetch("protected")
        serialized_header  = base64_decode(encoded_header)
        serialized_payload = ::JWT::JSON.generate(payload)
        encoded_payload    = base64_encode(serialized_payload)
        signature          = jws.fetch("signature")
        public_key         = public_keychain.with_indifferent_access.fetch(jws.fetch("header").fetch("kid"))
        jwt                = [encoded_header, encoded_payload, signature].join(".")
        algorithm          = ::JWT::JSON.parse(serialized_header).fetch("alg")
        JWT.decode(jwt, to_pem_or_key(public_key, algorithm), true, options.merge(algorithms: [algorithm])).first
      end

    private

      #
      # Transforms key into string (PEM format) or returns as {OpenSSL::PKey::PKey} depending on given algorithm.
      # This operation is needed to satisfy {JWT#encode} and {JWT#decode} APIs.
      #
      # @param key [String, OpenSSL::PKey::PKey]
      # @param algorithm [String]
      # @return [String, OpenSSL::PKey::PKey]
      #   Returns PEM for HMAC algorithms, {OpenSSL::PKey::PKey} in other cases.
      def to_pem_or_key(key, algorithm)
        if algorithm.start_with?("HS")
          OpenSSL::PKey::PKey === key ? key.to_pem : key
        else
          OpenSSL::PKey::PKey === key ? key : OpenSSL::PKey.read(key)
        end
      end

      #
      # Encodes string in Base64 format (URL-safe).
      #
      # @param string [String]
      # @return [String]
      if JWT::Encode.respond_to?(:base64url_encode)
        def base64_encode(string)
          JWT::Encode.base64url_encode(string)
        end
      else
        def base64_encode(string)
          JWT::Base64.url_encode(string)
        end
      end


      #
      # Decodes string from Base64 format (URL-safe).
      #
      # @param string [String]
      # @return [String]
      if JWT::Decode.respond_to?(:base64url_decode)
        def base64_decode(string)
          JWT::Decode.base64url_decode(string)
        end
      else
        def base64_decode(string)
          JWT::Base64.url_decode(string)
        end
      end
    end
  end
end

JWT::Multisig = JWT::Multisignature # Compatibility.
