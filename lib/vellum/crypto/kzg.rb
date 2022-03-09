# frozen_string_literal: true

require_relative "../algebra/msm"
require_relative "../algebra/polynomial"
require_relative "../algebra/pairing/bn254_pairing"

module Vellum
  module Crypto
    # Kate-Zaverucha-Goldberg (KZG) polynomial commitment scheme.
    # Enables constant-size O(1) commitments and evaluation proofs
    # verified with elliptic curve bilinear pairings.
    module KZG
      # Structured Reference String (Powers of Tau)
      class SRS
        attr_reader :g1_powers, :g2_powers, :max_degree, :pairing_engine

        def initialize(g1_powers, g2_powers, pairing_engine = Algebra::Pairing::BN254Pairing.instance)
          @g1_powers = g1_powers
          @g2_powers = g2_powers
          @max_degree = g1_powers.length - 1
          @pairing_engine = pairing_engine
        end

        # Generates a fresh SRS from a toxic secret tau (used for local setup and testing)
        def self.generate(degree, tau, pairing_engine = Algebra::Pairing::BN254Pairing.instance)
          g1 = pairing_engine.g1.generator
          g2 = pairing_engine.g2.generator
          order = pairing_engine.g1.order

          tau_val = tau.is_a?(Algebra::FieldElement) ? tau.value : tau.to_i
          curr_tau = 1

          g1_powers = []
          (degree + 1).times do
            g1_powers << (g1 * curr_tau)
            curr_tau = (curr_tau * tau_val) % order
          end

          g2_powers = [g2, g2 * (tau_val % order)]
          new(g1_powers, g2_powers, pairing_engine)
        end
      end

      # Opening proof representation
      class Proof
        attr_reader :commitment, :z, :y, :witness

        def initialize(commitment, z, y, witness)
          @commitment = commitment
          @z = z
          @y = y
          @witness = witness
        end
      end

      class << self
        # Setup helper generating a toxic SRS of given degree
        def setup(degree, pairing_engine = Algebra::Pairing::BN254Pairing.instance, tau = nil)
          order = pairing_engine.g1.order
          t = tau || (SecureRandom.random_number(order - 2) + 2)
          SRS.generate(degree, t, pairing_engine)
        end
      end

      class << self
        # Commits to polynomial P(X) using Pippenger MSM
        def commit(poly, srs)
          raise ArgumentError, "Polynomial degree (#{poly.degree}) exceeds SRS max degree (#{srs.max_degree})" if poly.degree > srs.max_degree
          return srs.g1_powers.first.curve.infinity if poly.zero?

          points = srs.g1_powers[0..poly.degree]
          scalars = poly.coeffs
          Algebra::MSM.multi_scalar_mul(points, scalars)
        end

        # Generates evaluation proof for P(z) = y:
        # Computes quotient polynomial Q(X) = (P(X) - y) / (X - z)
        # and proof witness W = [Q(tau)]_1.
        def open(poly, z, srs)
          z_elem = z.is_a?(Algebra::FieldElement) ? z : poly.field.element(z)
          y = poly.evaluate(z_elem)

          # Divisor polynomial: X - z
          divisor = Algebra::Polynomial.new(poly.field, [-z_elem, poly.field.one])
          poly_minus_y = poly - y

          # Compute quotient Q(X) = (P(X) - y) / (X - z)
          q_poly, rem = poly_minus_y.divmod(divisor)
          raise CryptoError, "Polynomial not divisible by X - z" unless rem.zero?

          witness = commit(q_poly, srs)
          commitment = commit(poly, srs)

          Proof.new(commitment, z_elem, y, witness)
        end

        # Verifies evaluation proof:
        # Checks pairing equation: e(witness, [tau - z]_2) == e(commitment - y*[1]_1, [1]_2)
        def verify(proof, srs)
          engine = srs.pairing_engine
          g1_gen = srs.g1_powers.first
          g2_gen = srs.g2_powers.first
          g2_tau = srs.g2_powers[1]

          # Left side: [tau - z]_2 = [tau]_2 - z*[1]_2
          tau_minus_z = g2_tau - (g2_gen * proof.z)

          # Right side: commitment - y*[1]_1
          y_g1 = g1_gen * proof.y
          c_minus_y = proof.commitment - y_g1

          # Multi-pairing check:
          # e(witness, tau_minus_z) == e(c_minus_y, g2_gen)
          # Equivalent to: e(witness, tau_minus_z) * e(-c_minus_y, g2_gen) == 1
          engine.check_pairing_identity([
            [proof.witness, tau_minus_z],
            [-c_minus_y, g2_gen]
          ])
        end

        # Batched KZG verification of multiple proofs at various evaluation points
        def batch_verify(proofs, srs, random_challenge)
          return true if proofs.empty?

          engine = srs.pairing_engine
          g1_gen = srs.g1_powers.first
          g2_gen = srs.g2_powers.first
          g2_tau = srs.g2_powers[1]

          # Combine proofs using random challenge gamma powers
          gamma = random_challenge
          curr_gamma = gamma.field.one

          lhs_sum = g1_gen.curve.infinity
          rhs_sum = g1_gen.curve.infinity

          proofs.each do |p|
            tau_minus_z = g2_tau - (g2_gen * p.z)
            c_minus_y = p.commitment - (g1_gen * p.y)

            # Accumulate terms
            lhs_term = p.witness * curr_gamma
            rhs_term = c_minus_y * curr_gamma

            lhs_sum = lhs_sum + lhs_term
            rhs_sum = rhs_sum + rhs_term

            curr_gamma = curr_gamma * gamma
          end

          # Verify batch pairing identity
          engine.check_pairing_identity([
            [lhs_sum, g2_tau],
            [-rhs_sum, g2_gen]
          ])
        end
      end
    end
  end
end
