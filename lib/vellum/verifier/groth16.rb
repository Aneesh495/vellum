# frozen_string_literal: true

require_relative "../algebra/msm"
require_relative "../algebra/pairing/bn254_pairing"

module Vellum
  module Verifier
    # Groth16 zero-knowledge verifier.
    # Evaluates the bilinear pairing identity:
    # e(A, B) == e(alpha, beta) * e(IC, gamma) * e(C, delta)
    # using a single consolidated multi-pairing check in GT.
    class Groth16
      class << self
        def verify(vk, public_inputs, proof, pairing_engine = Algebra::Pairing::BN254Pairing.instance)
          # Ensure public inputs length matches expected IC length (excluding IC[0] for constant 1)
          expected_pub_len = vk.ic.length - 1
          raise ArgumentError, "Public inputs mismatch: expected #{expected_pub_len}, got #{public_inputs.length}" unless public_inputs.length == expected_pub_len

          # 1. Compute IC = IC[0] + sum(x_i * IC[i])
          ic_points = vk.ic
          scalars = [1] + public_inputs
          ic_acc = Algebra::MSM.multi_scalar_mul(ic_points, scalars)

          # 2. Multi-pairing check:
          # e(A, -B) * e(alpha, beta) * e(IC, gamma) * e(C, delta) == 1
          neg_b = -proof.b

          pairs = [
            [proof.a, neg_b],
            [vk.alpha_g1, vk.beta_g2],
            [ic_acc, vk.gamma_g2],
            [proof.c, vk.delta_g2]
          ]

          pairing_engine.check_pairing_identity(pairs)
        end
      end
    end
  end
end
