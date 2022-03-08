# frozen_string_literal: true

require_relative "../algebra/curves/babyjubjub"
require_relative "poseidon/sponge"

module Vellum
  module Crypto
    # EdDSA digital signature scheme over the BabyJubJub twisted Edwards curve
    # using Poseidon algebraic hash. Designed specifically for in-circuit SNARK verification.
    module BabyJubJubEdDSA
      class Signature
        attr_reader :r_point, :s_scalar

        def initialize(r_point, s_scalar)
          @r_point = r_point
          @s_scalar = s_scalar
        end

        def to_h
          {
            rx: @r_point.to_affine.x.to_s,
            ry: @r_point.to_affine.y.to_s,
            s: @s_scalar.to_s
          }
        end
      end

      class << self
        def curve
          Algebra::Curves::BabyJubJub.instance
        end

        # Generates public key A = sk * B
        def public_key(secret_key)
          b = curve.base8
          b * secret_key
        end

        # Signs message scalar M using secret key
        def sign(secret_key, message)
          sk_val = secret_key.is_a?(Algebra::FieldElement) ? secret_key.value : secret_key.to_i
          m_val = message.is_a?(Algebra::FieldElement) ? message.value : message.to_i
          sub_order = curve.subgroup_order
          b = curve.base8

          # 1. Deterministic nonce derivation via Poseidon
          r_scalar = Poseidon.hash([sk_val, m_val]).value % sub_order
          r_point = b * r_scalar

          # 2. Compute public key
          pk_point = b * sk_val

          # 3. Compute Fiat-Shamir challenge h = Poseidon(Rx, Ry, Ax, Ay, M)
          rx = r_point.to_affine.x.value
          ry = r_point.to_affine.y.value
          ax = pk_point.to_affine.x.value
          ay = pk_point.to_affine.y.value

          h_scalar = Poseidon.hash([rx, ry, ax, ay, m_val]).value % sub_order

          # 4. Compute response s = (r + h * sk) mod l
          s_scalar = (r_scalar + (h_scalar * sk_val)) % sub_order

          Signature.new(r_point, s_scalar)
        end

        # Verifies signature (R, s) under public key A:
        # Checks s * B == R + h * A
        def verify(public_key, message, signature)
          sub_order = curve.subgroup_order
          b = curve.base8
          m_val = message.is_a?(Algebra::FieldElement) ? message.value : message.to_i

          rx = signature.r_point.to_affine.x.value
          ry = signature.r_point.to_affine.y.value
          ax = public_key.to_affine.x.value
          ay = public_key.to_affine.y.value

          # Compute challenge h
          h_scalar = Poseidon.hash([rx, ry, ax, ay, m_val]).value % sub_order

          # Left side: s * B
          lhs = b * signature.s_scalar

          # Right side: R + h * A
          h_times_a = public_key * h_scalar
          rhs = signature.r_point + h_times_a

          lhs == rhs
        end
      end
    end
  end
end
